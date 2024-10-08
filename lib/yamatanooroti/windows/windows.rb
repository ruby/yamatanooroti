require 'stringio'
require 'win32/registry'

module Yamatanooroti::WindowsConsoleSettings
  DelegationConsoleSetting = {
    conhost:  "{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}",
    terminal: "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}",
    preview:  "{06EC847C-C0A5-46B8-92CB-7C92F6E35CD5}",
  }.freeze
  DelegationTerminalSetting = {
    conhost:  "{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}",
    terminal: "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}",
    preview:  "{86633F1F-6454-40EC-89CE-DA4EBA977EE2}",
  }.freeze

  begin
    Win32::Registry::HKEY_CURRENT_USER.open('Console') do |reg|
      @orig_conhost = reg['ForceV2']
    end
  rescue Win32::Registry::Error
  end
  begin
    Win32::Registry::HKEY_CURRENT_USER.open('Console\%%Startup') do |reg|
      @orig_console = reg['DelegationConsole']
      @orig_terminal = reg['DelegationTerminal']
    end
  rescue Win32::Registry::Error
  end

  Test::Unit.at_start do
    case Yamatanooroti.options.windows.to_s
    when "conhost"
      Win32::Registry::HKEY_CURRENT_USER.open('Console', Win32::Registry::KEY_WRITE) do |reg|
        reg['ForceV2', Win32::Registry::REG_DWORD] = 1
      end
      Win32::Registry::HKEY_CURRENT_USER.open('Console\%%Startup', Win32::Registry::KEY_WRITE) do |reg|
        reg['DelegationConsole', Win32::Registry::REG_SZ] = DelegationConsoleSetting[:conhost]
        reg['DelegationTerminal', Win32::Registry::REG_SZ] = DelegationTerminalSetting[:conhost]
      end if @orig_console && @orig_terminal
    when "legacy-conhost"
      Win32::Registry::HKEY_CURRENT_USER.open('Console', Win32::Registry::KEY_WRITE) do |reg|
        reg['ForceV2', Win32::Registry::REG_DWORD] = 0
      end
      Win32::Registry::HKEY_CURRENT_USER.open('Console\%%Startup', Win32::Registry::KEY_WRITE) do |reg|
        reg['DelegationConsole', Win32::Registry::REG_SZ] = DelegationConsoleSetting[:conhost]
        reg['DelegationTerminal', Win32::Registry::REG_SZ] = DelegationTerminalSetting[:conhost]
      end if @orig_console && @orig_terminal
    end
  end

  Test::Unit.at_exit do
    Win32::Registry::HKEY_CURRENT_USER.open('Console', Win32::Registry::KEY_WRITE) do |reg|
      reg['ForceV2', Win32::Registry::REG_DWORD] = @orig_conhost
    end if @orig_conhost
    Win32::Registry::HKEY_CURRENT_USER.open('Console\%%Startup', Win32::Registry::KEY_WRITE) do |reg|
      reg['DelegationConsole', Win32::Registry::REG_SZ] = @orig_console
      reg['DelegationTerminal', Win32::Registry::REG_SZ] = @orig_terminal
    end if @orig_console && @orig_terminal
  end
end

module Yamatanooroti::WindowsTermMixin
  DL = Yamatanooroti::WindowsDefinition

  CONSOLE_KEEPING_COMMAND = %q[ruby.exe --disable=gems -e sleep]
  CONSOLE_MARKING_COMMAND = %q[findstr.exe yamatanooroti]

  private def attach_terminal(open = true)
    stderr = $stderr
    $stderr = StringIO.new

    conin = conout = nil
    check_interrupt
    DL.free_console
    # this can be fail while new process is starting
    r = DL.attach_console(@console_process_id, maybe_fail: true)
    return nil unless r

    if open
      conin = DL.create_console_file_handle("conin$")
      return nil if conin == DL::INVALID_HANDLE_VALUE

      conout = DL.create_console_file_handle("conout$")
      return nil if conout == DL::INVALID_HANDLE_VALUE
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
        begin
          Process.kill("KILL", @pid)
        rescue Errno::ESRCH # No such process
        end
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
      buffer = ""
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
    attach_terminal do
      @target = SubProcess.new(command.map{ |c| quote_command_arg(c) }.join(' '))
    end
  end

  def setup_cp(cp)
    @codepage_success_p = attach_terminal { system("chcp #{Integer(cp)} > NUL") }
  end

  def codepage_success?
    @codepage_success_p
  end

  def write(str)
    check_interrupt
    codes = str.chars.map do |c|
      c = "\r" if c == "\n"
      byte = c.getbyte(0)
      if c.bytesize == 1 and byte.allbits?(0x80) # with Meta key
        [-(byte ^ 0x80)]
      else
        DL.mb2wc(c).unpack("S*")
      end
    end.flatten
    record = DL::INPUT_RECORD_WITH_KEY_EVENT.malloc(DL::FREE)
    records = codes.reduce("".b) do |records, code|
      DL.set_input_record(record, code)
      record.bKeyDown = 1
      records << record.to_ptr.to_str
      record.bKeyDown = 0
      records << record.to_ptr.to_str
    end
    attach_terminal do |conin, conout|
      DL.write_console_input(conin, records, codes.size * 2)
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

  def retrieve_screen(top_of_buffer: false)
    return @result if @result
    check_interrupt
    @target.sync
    top, bottom, width = attach_terminal do |conin, conout|
      csbi = DL.get_console_screen_buffer_info(conout)
      if top_of_buffer
        [0, csbi.Bottom, csbi.Right - csbi.Left + 1]
      else
        [csbi.Top, csbi.Bottom, csbi.Right - csbi.Left + 1]
      end
    end

    lines = attach_terminal do |conin, conout|
      (top..bottom).map do |y|
        DL.read_console_output(conout, y, width) || ""
      end
    end
    lines
  end

  def result
    @result || retrieve_screen
  end

  def check_interrupt
    raise_interrupt if DL.interrupted?
  end

  def raise_interrupt
    close_console
    DL.at_exit
    raise Interrupt
  end
end
