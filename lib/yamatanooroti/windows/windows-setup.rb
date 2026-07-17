require 'win32/registry'
require 'tmpdir'
require 'fileutils'
require 'uri'
require 'digest/sha2'

module Yamatanooroti::WindowsConsoleSetup
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
    if @wt_exe
      Yamatanooroti::WindowsTerminalTerm.diagnose_size_capability
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
    running_wt_exist = false
    if File.exist?(extract_dir)
      wt = Dir["**/OpenConsole.exe", base: extract_dir]
      running_wt_exist = wt.reduce(false) do |result, path|
        result ||= begin
          File.delete(File.join(extract_dir, path))
          false
        rescue SystemCallError
          true
        end
      end
      FileUtils.remove_entry(extract_dir) if !running_wt_exist
    end
    if !running_wt_exist
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
                "experimental.detectURLs": false,
                "minimizeToNotificationArea": false,
                "profiles": 
                {
                    "defaults": 
                    {
                        "bellStyle": "none",
                        "closeOnExit": "always",
                        "font": 
                        {
                            "size": 9
                        },
                        "padding": "0",
                        "scrollbarState": "always"
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
                "showTabsInTitlebar": false,
                "tabWidthMode": "compact",
                "warning.confirmCloseAllTabs": false,
                "warning.largePaste": false,
                "warning.multiLinePaste": false
            }
        JSON
      end
      puts "use #{wt} for windows console"
    else
      puts "running Windows Terminal found."
      wt = Dir["**/wt.exe", base: extract_dir]
      raise "not found wt.exe. aborted." if wt.size < 1
      raise "found wt.exe #{wt.size} times unexpectedly. aborted." if wt.size > 1
      wt = File.join(extract_dir, wt[0])
      wt_dir = File.dirname(wt)
      puts "use existing #{wt} for windows console"
    end
    wt
  end

  def self.prepare_terminal_canary
    dir = tmpdir
    header = `curl --head -sS -o #{tmpdir}/header -L -w "%{url_effective}\n%header{ETag}\n%header{Content-Length}\n%header{Last-Modified}" https://aka.ms/terminal-canary-zip-x64`
    url, etag, length, timestamp = *header.lines.map(&:chomp)
    puts "Windows Terminal canary #{timestamp}"
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
