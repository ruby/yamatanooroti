require 'stringio'

module Yamatanooroti::WindowsTermMixin
  DL = Yamatanooroti::WindowsDefinition

  CONSOLE_KEEPING_COMMANDNAME = "ruby.exe"
  CONSOLE_KEEPING_COMMANDLINE = %q[ruby.exe --disable=gems -e "Signal.trap(:INT, nil) and sleep or sleep # SIG"]

  module_function def keeper_commandname
    CONSOLE_KEEPING_COMMANDNAME
  end

  module_function def keeper_commandline(signature)
    CONSOLE_KEEPING_COMMANDLINE.sub("SIG", signature)
  end

  module_function def show_console_param
    map = DL::SHOWWINDOW_MAP[Yamatanooroti.options.windows] || DL::SHOWWINDOW_MAP[:terminal]
    map.fetch(Yamatanooroti.options.show_console ? :show : :hide)
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

  private def attach_terminal(open: true, exception: true)
    stderr = $stderr
    $stderr = StringIO.new

    conin = conout = nil
    check_interrupt
    return nil if !console_process_id
    DL.free_console
    # this can be fail while new process is starting
    r = DL.attach_console(console_process_id, maybe_fail: !exception)
    return nil unless r

    if open
      # if error occurred, causes exception regardless of exception: false
      conin = DL.create_console_file_handle("conin$")
      conout = DL.create_console_file_handle("conout$")
    end

    yield(conin, conout)
  rescue => evar
  ensure
    DL.close_handle(conin) if conin && conin != DL::INVALID_HANDLE_VALUE
    DL.close_handle(conout) if conout && conout != DL::INVALID_HANDLE_VALUE
    DL.free_console
    DL.attach_console
    stderr.write $stderr.string
    $stderr = stderr
    raise evar if evar
  end

  private def quote_command_arg(arg)
    if not arg.match?(/[ \t"<>|()]/)
      # No quotation needed.
      return arg
    end

    if not arg.match?(/["\\]/)
      # No embedded double quotes or backlashes, so I can just wrap quote
      # marks around the whole thing.
      return %{"#{arg}"}
    end

    quote_hit = true
    result = +'"'
    arg.chars.reverse.each do |c|
      result << c
      if quote_hit and c == '\\'
        result << '\\'
      elsif c == '"'
        quote_hit = true
        result << '\\'
      else
        quote_hit = false
      end
    end
    result << '"'
    result.reverse
  end

  class SubProcess
    def initialize(command)
      @errin, err = IO.pipe
      DL.restore_console_control_handler do
        @pid = spawn(command, {in: ["conin$", File::RDWR | File::BINARY], out: ["conout$", File::RDWR | File::BINARY], err: err})
      end
      @mon = Process.detach(@pid)
      err.close
      @closed = false
      @status = nil
      @q = Thread::Queue.new
      @t = Thread.new do
        begin
          err = @errin.gets
          @q << err if err
        rescue IOError
          # target process already terminated
          next
        end
      end
    end

    def close
      unless closed?
        system("taskkill /PID #{@pid} /F /T", {[:out, :err] => "NUL"})
        @status = @mon.join.value.exitstatus
        sync
        @errin.close
      end
    end

    def closed?
      !@mon.alive?
    end

    private def consume(buffer)
      while !@q.empty?
        buffer << @q.shift
      end
    end

    def sync
      buffer = +""
      if closed?
        if !@errin.closed?
          @t.kill
          @t.join
          consume(buffer)
          rest = "".b
          while ((str = @errin.read_nonblock(1024, exception: false)).is_a?(String)) do
            rest << str
          end
          buffer << rest.force_encoding(Encoding.default_external) << "\n" if rest != ""
        end
      else
        consume(buffer)
      end
      $stderr.write buffer if buffer != ""
    end
  end

  def launch(command)
    check_interrupt
    attach_terminal(open: false) do
      @target = SubProcess.new(command.map{ |c| quote_command_arg(c) }.join(' '))
    end
  end

  def setup_cp(cp)
    @codepage_success_p = attach_terminal(open: false) do
      system("chcp #{Integer(cp)} > NUL")
      DL.get_console_codepage() == cp && DL.get_console_output_codepage() == cp
    end
  end

  def codepage_success?
    @codepage_success_p
  end

  private def do_write(str)
    check_interrupt
    records, count = DL.build_key_input_record(str)
    attach_terminal do |conin, conout|
      DL.write_console_input(conin, records, count)
      loop do
        sleep @wait
        n = DL.get_number_of_console_input_events(conin)
        break if n <= 1  # maybe keyup event still be there
        break if n.nil?
        @target.sync
        break if @target.closed?
      end
    end
  end

  def write(str)
    mode = attach_terminal { |conin, conout| DL.get_console_mode(conin) }
    if 0 == (mode & DL::ENABLE_PROCESSED_INPUT)
      do_write(str)
    else
      str.dup.force_encoding(Encoding::ASCII_8BIT).split(/(\C-c)/).each do |chunk|
        if chunk == "\C-c"
          attach_terminal(open: false) do
            # generate Ctrl+C event to process on same console
            DL.generate_console_ctrl_event(0, 0)
          end
        else
          do_write(chunk.force_encoding(str.encoding)) if chunk != ""
        end
      end
    end
    @wrote_and_not_yet_waited = true
  end

  def retrieve_screen(top_of_buffer: false)
    return @result if @result
    check_interrupt
    @target.sync
    attach_terminal do |conin, conout|
      csbi = DL.get_console_screen_buffer_info(conout)
      top, bottom, width = if top_of_buffer
        [0, csbi.Bottom, csbi.Right - csbi.Left + 1]
      else
        [csbi.Top, csbi.Bottom, csbi.Right - csbi.Left + 1]
      end

      return (top..bottom).map do |y|
        DL.read_console_output(conout, y, width) || ""
      end
    end
  end

  def result
    @result || retrieve_screen
  end

  def close
    close_request = @target && !@target.closed?
    retrieve_request = !DL.interrupted? && console_process_id

    if close_request && retrieve_request && !@result
      if @wrote_and_not_yet_waited # wait a long. avoid write();close() sequence
        sleep @timeout
        puts "\r#{@name}: close() just after write() will ultimately slow test down. use close() after assert_screen()."
      end
    end

    @target.close if close_request
    @result = retrieve_screen if retrieve_request
    @result ||= ""
  end

  def clear_need_wait_flag
    @wrote_and_not_yet_waited = false
  end

  # identify windows console
  # conhost(legacy)
  #   compatible with older windows
  #   lacks newer features (VT sequence support)
  # conhost(classic)
  #   conhost with supports VT
  # terminal
  #   fully VT support
  #   focused on modern features over compatibility 
  #     can't access screen buffer outside of view
  #     change winsize using win32api
  def identify
    attach_terminal do |conin, conout|
      orig_mode = DL.get_console_mode(conout)
      DL.set_console_mode(conout, orig_mode ^ DL::ENABLE_VIRTUAL_TERMINAL_PROCESSING)
      alt_mode = DL.get_console_mode(conout)
      if ((orig_mode | alt_mode) & DL::ENABLE_VIRTUAL_TERMINAL_PROCESSING) == 0
        # consolemode unchanged, ENABLE_VIRTUAL_TERMINAL_PROCESSING == 0
        return :"legacy-conhost"
      end
      DL.set_console_mode(conout, orig_mode)

      orig_buffer_info = DL.get_console_screen_buffer_info(conout)
      view_w = orig_buffer_info.dwSize_X
      view_h = orig_buffer_info.Bottom - orig_buffer_info.Top + 1
      buffer_height = orig_buffer_info.dwSize_Y
      if buffer_height !=  view_h
        # buffer size != view size
        return :conhost
      end

      DL.set_console_screen_buffer_info_ex(conout,  view_h,  view_w, buffer_height + 1)
      alt_buffer_info = DL.get_console_screen_buffer_info(conout)
      if alt_buffer_info.dwSize_Y == buffer_height + 1
        # now screen buffer size can be diffrent to view size
        DL.set_console_screen_buffer_info_ex(conout,  view_h,  view_w, buffer_height)
        return :conhost
      else
        DL.set_console_window_info(conout, view_h, view_w)
        return :terminal
      end
    end
  end

  def check_interrupt
    raise_interrupt if DL.interrupted?
  end

  def raise_interrupt
    @target.close
    close!
    DL.at_exit
    raise Interrupt
  end
end
