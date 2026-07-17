class Yamatanooroti

  ### Yamatanooroti::WindowsTerminal
  #
  # represents windows terminal window
  #

  class WindowsTerminal
    Self = self
    class << self
      attr_reader :split_cache_h, :split_cache_v
    end

    @split_cache_h = {}
    @split_cache_v = {}

    attr_reader :name, :title, :testcase, :wt_command, :wait, :timeout, :active_tab, :base_tab

    def initialize(rows, cols, name, title, wait, timeout, testcase)
      @name = name
      @title = title
      @wait = wait
      @timeout = timeout
      @testcase = testcase
      @wt_command = "#{Yamatanooroti::WindowsConsoleSetup.wt_exe} " \
                    "-w #{title} " \
                    "--size #{cols},#{rows} "
      @tabs = []
      @active_tab = nil
      @base_tab = Tab.new_tab(self, title)
    end

    def new_tab(height, width, title)
      base_height, base_width = @base_tab.get_size
      if height > base_height
        raise "console height #{height} grater than maximum(#{base_height})"
      end
      if width > base_width
        raise "console width #{width} grater than maximum(#{base_width})"
      end

      hsplitter = Self.split_cache_h[base_height] || SplitSizeManager.new(base_height)
      vsplitter = Self.split_cache_v[base_width] || SplitSizeManager.new(base_width)

      hsplit = hsplitter.query(height)
      vsplit = vsplitter.query(width)
      begin
        if hsplit && vsplit
          tab = Tab.new_tab_hv(self, title, hsplit[0].to_f / hsplit[1], vsplit[0].to_f / vsplit[1])
          if tab.get_size == [height, width]
            return tab
          else
            tab.close_pane
            tab.close_pane
          end
        else
          tab = Tab.new_tab(self, title)
        end

        if height != base_height
          hsplit = hsplitter.search_div(height) do |div|
            tab.split_pane(div, splitter: :h)
            h = tab.get_size[0]
            tab.close_pane if h != height
            h
          end
          raise "console height deviding to #{height} failed" if !hsplit
        end

        if width != base_width
          vsplit = vsplitter.search_div(width) do |div|
            tab.split_pane(div, splitter: :v)
            w = tab.get_size[1]
            tab.close_pane if w != width
            w
          end
          raise "console widtht deviding to #{width} failed" if !vsplit
        end

        return tab
      ensure
        @tabs << tab
        @active_tab = tab
        Self.split_cache_h[base_height] = hsplitter
        Self.split_cache_v[base_width] = vsplitter
      end
    end

    def close_tab
      if @active_tab
        @active_tab.close
        @active_tab = nil
        @tabs.pop
      end
    end

    def detach_tab
      if @active_tab
        @active_tab.detach
        @active_tab = nil
        @tabs.pop
      end
    end

    def close
      @active_tab&.close
      @base_tab&.close
      @base_tab = @active_tab = nil
    end

    ### Yamatanooroti::WindowsTerminal::Tab
    #
    # represents and manipulates windows terminal tab
    #

    class Tab
      include Yamatanooroti::WindowsTermMixin
      M = WindowsTermMixin
      attr_reader :wt, :name, :title

      def raise_interrupt
        wt.testcase.raise_interrupt
      end

      private_class_method :new

      def initialize(wt, title, *handles)
        @wt = wt
        @wait = wt.wait
        @timeout = wt.timeout
        @name = wt.name
        @title = title
        @closed = false
        @handles = handles
        @pid = nil
      end

      def self.new_tab(wt, title)
        pipename = M.get_pipename(title, "main")
        pipe_handle = DL.create_named_pipe(pipename)
        keeper_command = M.keeper_commandline(pipename)
        command = "#{wt.wt_command} " \
                  "nt --title #{title} " \
                  "#{keeper_command}"

        DL.create_console(command, M.show_console_param())
        new(wt, title, pipe_handle)
      end

      def self.new_tab_hv(wt, title, hsplit, vsplit)
        main_pipename = M.get_pipename(title, "main")
        h_pipename = M.get_pipename(title, "h")
        v_pipename = M.get_pipename(title, "v")
        main_pipe_handle = DL.create_named_pipe(main_pipename)
        h_pipe_handle = DL.create_named_pipe(h_pipename)
        v_pipe_handle = DL.create_named_pipe(v_pipename)
        keeper_command = M.keeper_commandline(main_pipename)
        keeper_command_h = M.keeper_commandline(h_pipename)
        keeper_command_v = M.keeper_commandline(v_pipename)
        command = "#{wt.wt_command} " \
                  "nt --title #{title} " \
                  "#{keeper_command}" \
                  "; " \
                  "sp -H "\
                  "--title #{title} " \
                  "-s #{hsplit} " \
                  "#{keeper_command_h}" \
                  "; " \
                  "move-focus first; " \
                  "sp -V "\
                  "--title #{title} " \
                  "-s #{vsplit} " \
                  "#{keeper_command_v}"

        DL.create_console(command, M.show_console_param())
        new(wt, title, main_pipe_handle, h_pipe_handle, v_pipe_handle)
      end

      def split_pane(div = 0.5, splitter: :v)
        pipename = get_pipename(title, ":#{splitter}")
        pipe_handle = DL.create_named_pipe(pipename)
        keeper_command = M.keeper_commandline(pipename)
        command = "#{@wt.wt_command} " \
                  "move-focus first; " \
                  "sp #{splitter == :v ? "-V" : "-H"} "\
                  "--title #{title} " \
                  "-s #{div} " \
                  "#{keeper_command}"

        orig_size = get_size()
        DL.create_console(command, show_console_param())
        @handles.push pipe_handle
        with_timeout("split console timed out.") { orig_size != get_size() }
      end

      def close_pane
        orig_size = get_size()
        DL.close_handle(@handles.pop)
        with_timeout("close pane timed out.") { orig_size != get_size() }
      end

      def close
        unless @closed
          @handles.each do |pipe_handle|
            DL.close_handle(pipe_handle)
          end
          @handles.clear
        end
        @closed = true
      end

      def detach
        unless @closed
          @handles.each do |pipe_handle|
           castling(pipe_handle)
          end
          @handles.clear
        end
        @closed = true
      end

      def console_process_id
        @pid ||= get_pid_from_pipe(@handles[0])
      end

      def get_size
        attach_terminal do |conin, conout|
          csbi = DL.get_console_screen_buffer_info(conout)
          [csbi.Bottom + 1, csbi.Right + 1]
        end
      end
    end

    ### Yamatanooroti::WindowsTerminal::SplitSizeManager
    #
    # cache manager of windows terminal pane splitter divisor parameter
    #

    class SplitSizeManager
      def initialize(total)
        @total = total
        @div_to_x = {}
        @x_to_div = {}
      end

      def query(x)
        @x_to_div[x]
      end

      def search_div(x, &block)
        denominator = 200
        div, denominator = @x_to_div[x] if @x_to_div[x]
        div ||= 2 * ((@total - x) * (denominator * 97) / @total + denominator * 2) / 200
        loop do
          result = block.call(div.to_f / denominator)
          @div_to_x[div.to_f / denominator] = result
          @x_to_div[x] = [div, denominator]
          return result if result == x
          if result < x
            div -= 1
            return nil if div <= 0
            if @div_to_x[div.to_f / denominator] && @div_to_x[div.to_f / denominator] != x
              div = div * 2 + 1
              denominator *= 2
            end
          else
            div += 1
            return nil if div >= denominator
            if @div_to_x[div.to_f / denominator] && @div_to_x[div.to_f / denominator] != x
              div = div * 2 - 1
              denominator *= 2
            end
          end
        end
      end
    end
  end
end
