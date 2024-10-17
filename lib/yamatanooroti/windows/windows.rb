require 'stringio'
require 'win32/registry'
require 'tmpdir'
require 'fileutils'
require 'uri'
require 'digest/sha2'

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

  def self.wt_exe
    @wt_exe
  end

  def self.wt_wait
    0
  end

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
    case Yamatanooroti.options.windows
    when :conhost
      puts "use conhost(classic, conhostV2) for windows console"
      Win32::Registry::HKEY_CURRENT_USER.open('Console', Win32::Registry::KEY_WRITE) do |reg|
        reg['ForceV2', Win32::Registry::REG_DWORD] = 1
      end
      Win32::Registry::HKEY_CURRENT_USER.open('Console\%%Startup', Win32::Registry::KEY_WRITE) do |reg|
        reg['DelegationConsole', Win32::Registry::REG_SZ] = DelegationConsoleSetting[:conhost]
        reg['DelegationTerminal', Win32::Registry::REG_SZ] = DelegationTerminalSetting[:conhost]
      end if @orig_console && @orig_terminal
    when :"legacy-conhost"
      puts "use conhost(legacy, conhostV1) for windows console"
      Win32::Registry::HKEY_CURRENT_USER.open('Console', Win32::Registry::KEY_WRITE) do |reg|
        reg['ForceV2', Win32::Registry::REG_DWORD] = 0
      end
      Win32::Registry::HKEY_CURRENT_USER.open('Console\%%Startup', Win32::Registry::KEY_WRITE) do |reg|
        reg['DelegationConsole', Win32::Registry::REG_SZ] = DelegationConsoleSetting[:conhost]
        reg['DelegationTerminal', Win32::Registry::REG_SZ] = DelegationTerminalSetting[:conhost]
      end if @orig_console && @orig_terminal
    when :canary
      @wt_exe = extract_terminal(prepare_terminal_canary)
    else
      @wt_exe = extract_terminal(prepare_terminal_portable)
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

  def self.tmpdir
    return @tmpdir if @tmpdir
    dir = nil
    if Yamatanooroti.options.terminal_workdir
      dir = Yamatanooroti.options.terminal_workdir
      FileUtils.mkdir_p(dir)
    else
      @tmpdir_t = Thread.new do
        Thread.current.abort_on_exception = true
        Dir.mktmpdir do |tmpdir|
          dir = tmpdir
          p dir
          sleep
        ensure
          sleep 0.5 # wait for terminate windows terminal
        end
      end
      Thread.pass while dir == nil
    end
    return @tmpdir = dir
  end

  def self.extract_terminal(path)
    tar = File.join(ENV['SystemRoot'], "system32", "tar.exe")
    extract_dir = File.join(tmpdir, "wt")
    FileUtils.remove_entry(extract_dir) if File.exist?(extract_dir)
    FileUtils.mkdir_p(extract_dir)
    puts "extracting #{File.basename(path)}"
    system tar, "xf", path, "-C", extract_dir
    wt = Dir["**/wt.exe", base: extract_dir]
    raise "not found wt.exe. aborted." if wt.size < 1
    raise "found wt.exe #{wt.size} times unexpectedly. aborted." if wt.size > 1
    wt = File.join(extract_dir, wt[0])
    wt_dir = File.dirname(wt)
    portable_mark = File.join(wt_dir, ".portable")
    open(portable_mark, "w") { |f| f.puts } unless File.exist?(portable_mark)
    settings = File.join(wt_dir, "settings", "settings.json")
    FileUtils.mkdir_p(File.dirname(settings))
    open(settings, "wb") do |settings|
      settings.write <<~'JSON'
          {
              "defaultProfile": "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}",
              "disableAnimations": true,
              "profiles": 
              {
                  "defaults": 
                  {
                      "bellStyle": "none",
                      "closeOnExit": "always",
                      "font": 
                      {
                          "size": 9
                      }
                  },
                  "list": 
                  [
                      {
                          "commandline": "%SystemRoot%\\System32\\cmd.exe",
                          "guid": "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}",
                          "name": "cmd.exe"
                      }
                  ]
              },
              "warning.confirmCloseAllTabs": false,
              "warning.largePaste": false,
              "warning.multiLinePaste": false
          }
      JSON
    end
    puts "use #{wt} for windows console"
    wt
  end

  def self.prepare_terminal_canary
    dir = tmpdir
    header = `curl --head -sS -o #{tmpdir}/header -L -w "%{url_effective}\n%header{ETag}\n%header{Content-Length}\n%header{Last-Modified}" https://aka.ms/terminal-canary-zip-x64`
    url, etag, length, timestamp = *header.lines.map(&:chomp)
    name = File.basename(URI.parse(url).path)
    path = File.join(dir, "wt_dists", "canary", etag.delete('"'), name)
    if File.exist?(path)
      if File.size(path) == length.to_i
        puts "use existing #{path}"
        return path
      else
        FileUtils.remove_entry(path)
      end
    else
      if Dir.empty?(dir)
        puts "removing old canary zip"
        Dir.entries.each { |olddir| FileUtils.remove_entry(olddir) }
      end
    end
    FileUtils.mkdir_p(File.dirname(path))
    system "curl #{$stdin.isatty ? "" : "-sS "}-L -o #{path} https://aka.ms/terminal-canary-zip-x64"
    path
  end

  def self.prepare_terminal_portable
    releases = Yamatanooroti::Options::WindowsTerminal::RELEASES
    url = releases[Yamatanooroti.options.windows.to_sym][:url]
    sha256 = releases[Yamatanooroti.options.windows.to_sym][:sha256]
    dir = tmpdir
    name = File.basename(URI.parse(url).path)
    path = File.join(dir, "wt_dists", Yamatanooroti.options.windows, name)
    if File.exist?(path)
      if Digest::SHA256.new.file(path).hexdigest.upcase == sha256
        puts "use existing #{path}"
        return path
      else
        FileUtils.remove_entry(path)
      end
    end
    FileUtils.mkdir_p(File.dirname(path))
    system "curl #{$stdin.isatty ? "" : "-sS "}-L -o #{path} #{url}"
    raise "not match windows terminal distribution zip sha256" unless Digest::SHA256.new.file(path).hexdigest.upcase == sha256
    path
  end
end

module Yamatanooroti::WindowsTermMixin
  DL = Yamatanooroti::WindowsDefinition

  CONSOLE_KEEPING_COMMAND = %q[ruby.exe --disable=gems -e "Signal.trap(:INT, nil); sleep"]
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
    attach_terminal(false) do
      @target = SubProcess.new(command.map{ |c| quote_command_arg(c) }.join(' '))
    end
  end

  def setup_cp(cp)
    @codepage_success_p = attach_terminal(false) do
      system("chcp #{Integer(cp)} > NUL")
      DL.get_console_codepage() == cp && DL.get_console_output_codepage() == cp
    end
  end

  def codepage_success?
    @codepage_success_p
  end

  def do_write(str)
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

  def write(str)
    mode = attach_terminal { |conin, conout| DL.get_console_mode(conin) }
    if 0 == (mode & DL::ENABLE_PROCESSED_INPUT)
      do_write(str)
    else
      str.dup.force_encoding(Encoding::ASCII_8BIT).split(/(\C-c)/).each do |chunk|
        if chunk == "\C-c"
          attach_terminal(false) do
            # generate Ctrl+C event to process on same console
            DL.generate_console_ctrl_event(0, 0)
          end
        else
          do_write(chunk.force_encoding(str.encoding)) if chunk != ""
        end
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
    close_console
    DL.at_exit
    raise Interrupt
  end
end
