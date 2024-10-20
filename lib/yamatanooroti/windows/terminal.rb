class Yamatanooroti::WindowsTerminalTerm
  include Yamatanooroti::WindowsTermMixin

  @@count = 0
  @@cradle = {}

  def call_spawn(command)
    pid = spawn(command)
    if t = Process.detach(pid)
      @@cradle[pid] = t
    end
    pid
  end

  def kill_and_wait(pid)
    return unless pid
    t = @@cradle[pid]
    begin
      Process.kill(:KILL, pid)
    rescue Errno::ESRCH # No such process
    end
    if t
      if t.join(@timeout) == nil
        puts "Caution: process #{pid} does not terminate in #{@timeout} seconds."
      end
      @@cradle.delete(pid)
    end
  end

  def get_size
    attach_terminal do |conin, conout|
      csbi = DL.get_console_screen_buffer_info(conout)
      [csbi.Bottom + 1, csbi.Right + 1]
    end
  end

  def do_tasklist(filter)
    list = `tasklist /FI "#{filter}"`.lines
    if list.length != 4
      return nil
    end
    pid_start = list[2].index(/ \K=/)
    list[3][pid_start..-1].to_i
  end

  def pid_from_imagename(name)
    do_tasklist("IMAGENAME eq #{name}")
  end

  def pid_from_windowtitle(name)
    do_tasklist("WINDOWTITLE eq #{name}")
  end

  private def with_timeout(timeout_message, timeout = @timeout, &block)
    wait_until = Time.now + timeout
    loop do
      result = block.call
      break result if result
      raise timeout_message if wait_until < Time.now
      sleep @wait
    end
  end

  private def invoke_wt_process(command, marker, keeper_name)
    DL.create_console(command, show_console_param())
    # default timeout seems to be too short
    begin
      marker_pid = with_timeout("Windows Terminal marker process detection failed.", @timeout + 5) do
        pid_from_imagename(marker)
      end
    rescue => e
      # puts `tasklist /FI "SESSION ge 0"`
      raise e
    end
    @console_process_id = marker_pid

    # wait for console startup complete
    with_timeout("Console process startup timed out.") do
      attach_terminal(open: false, exception: false) { true }
    end

    keeper_pid = attach_terminal(open: false) do
      call_spawn(CONSOLE_KEEPING_COMMAND.sub("NAME", keeper_name))
    end
    @console_process_id = keeper_pid

    # wait for console keeping process startup complete
    with_timeout("Console process startup timed out.") do
      attach_terminal(open: false, exception: false) { true }
    end

    return keeper_pid
  ensure
    kill_and_wait(marker_pid) if marker_pid
  end

  def new_wt(rows, cols)
    marker_command = CONSOLE_MARKING_COMMAND

    @wt_id = "yamaoro#{Process.pid}##{@@count}"
    @@count += 1
    command = "#{Yamatanooroti::WindowsConsoleSettings.wt_exe} -w #{@wt_id} --size #{cols},#{rows} nt --title #{@wt_id} #{marker_command}"

    return invoke_wt_process(command, marker_command.split(" ").first, "new_wt")
  end

  def split_pane(div = 0.5, splitter: :v, name: nil)
    marker_command = CONSOLE_MARKING_COMMAND

    command = "#{Yamatanooroti::WindowsConsoleSettings.wt_exe} " \
              "-w #{@wt_id} " \
              "move-focus first; " \
              "sp #{splitter == :v ? "-V" : "-H"} "\
              "--title #{name || @wt_id} " \
              "-s #{div} " \
              "#{marker_command}"
    pid = invoke_wt_process(command, marker_command.split(" ").first, "split_pane")
    @process_ids.push pid
    @console_process_id = @process_ids[0]
  end

  def move_focus(direction)
    command = "#{Yamatanooroti::WindowsConsoleSettings.wt_exe} " \
              "-w #{@wt_id} " \
              "move-pane #{direction}"
    system(command)
  end

  def new_tab
    marker_command = CONSOLE_MARKING_COMMAND

    command = "#{Yamatanooroti::WindowsConsoleSettings.wt_exe} " \
              "-w #{@wt_id} " \
              "new-tab " \
              "#{marker_command}"
    invoke_wt_process(command, marker_command.split(" ").first, "new_tab")
  end

  def close_pane
    kill_and_wait(@process_ids.pop)
  end

  class List
    def initialize(total)
      @total = total
      @div_to_x = {}
      @x_to_div = {}
    end

    def search_div(x, &block)
      denominator = 100
      div, denominator = @x_to_div[x] if @x_to_div[x]
      div ||= (@total - x) * (denominator * 95 / 100) / @total + denominator * 4 / 100
      loop do
        # STDOUT.write "target: #{x} total: #{@total} div: #{div.to_f / denominator}"
        result = block.call(div.to_f / denominator)
        # puts " result: #{result}"
        @div_to_x[div.to_f / denominator] = result
        @x_to_div[x] = [div, denominator]
        return result if result == x
        if result < x
          div -= 1
          return nil if div <= 0
          if @div_to_x[div.to_f / denominator] && @div_to_x[div.to_f / denominator] != x
            div = div * 10 + 5
            denominator *= 10
          end
        else
          div += 1
          return nil if div >= denominator
          if @div_to_x[div.to_f / denominator] && @div_to_x[div.to_f / denominator] != x
            div = div * 10 - 5
            denominator *= 10
          end
        end
      end
    end
  end

  @@mother_wt = nil
  @@div_to_width = {}
  @@width_to_div = {}

  # raise "Could not set Windows Terminal to size #{[height, width]}"

  def self.setup_console(height, width, wait, timeout, name)
    if @@mother_wt == nil
      @@mother_wt = self.new(*@@max_size, wait, timeout)
      @@hsplit_info = List.new(@@max_size[0])
      @@vsplit_info = List.new(@@max_size[1])
    end
    mother_height = @@max_size[0]
    mother_width = @@max_size[1]

    if height > mother_height
      raise "console height #{height} grater than maximum(#{mother_height})"
    end
    if width > mother_width
      raise "console width #{width} grater than maximum(#{mother_width})"
    end

    if height != mother_height
      result_h = @@hsplit_info.search_div(height) do |div|
        @@mother_wt.split_pane(div, splitter: :h, name: name)
        @@mother_wt.move_focus("first")
        h = @@mother_wt.get_size[0]
        @@mother_wt.close_pane if h != height
        h
      end
      raise "console height deviding to #{height} failed" if !result_h
    end

    if width != mother_width
      result_w = @@vsplit_info.search_div(width) do |div|
        @@mother_wt.split_pane(div, splitter: :v, name: name)
        @@mother_wt.move_focus("first")
        w = @@mother_wt.get_size[1]
        @@mother_wt.close_pane if w != width
        w
      end
      raise "console widtht deviding to #{width} failed" if !result_w
    end

    return @@mother_wt
  end

  def initialize(height, width, wait, timeout)
    @wait = wait
    @timeout = timeout
    @result = nil
    @codepage_success_p = nil
    @wrote_and_not_yet_waited = false

    @process_ids = [new_wt(height, width)]
  end

  def self.diagnose_size_capability
    wt = self.new(999, 999, 0.01, 5.0)
    max_size = wt.get_size
    @@max_size = [[max_size[0], 60].min, [max_size[1], 200].min]
    puts max_size.then { "Windows Terminal maximum size: rows: #{_1}, columns: #{_2}" }
    wt.close!
    wt = self.new(2, 2, 0.01, 5.0)
    min_size = @@min_size = wt.get_size
    puts min_size.then { "Windows Terminal smallest size: rows: #{_1}, columns: #{_2}" }
    wt.close!
    puts @@max_size.then { "Use test window size: rows: #{_1}, columns: #{_2}" }
  end

  def close_console(need_to_close = true)
    nt = new_tab()
    if need_to_close && @process_ids
      if @target && !@target.closed?
        @target.close
      end
      while @process_ids.size > 0
        kill_and_wait(@process_ids.pop)
      end
    end
    @process_ids = [@console_process_id = nt]
    @result = nil
  end

  def close!
    if @process_ids
      while @process_ids.size > 0
        kill_and_wait(@process_ids.pop)
      end
    end
    @@mother_wt = nil
    @process_ids = @console_process_id = nil
  end

  Test::Unit.at_exit do
    @@mother_wt&.close!
  end
end
