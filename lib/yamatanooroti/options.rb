class Yamatanooroti
  module Options
    options = [
      :default_wait,
      :default_timeout,

      # windows console selection
      :windows,

      # true if conhost(classic) or conhost(legacy)
      :conhost,

      # true if windows terminal
      :terminal,

      # windows terminal download/extract dir
      :terminal_workdir,

      # show console window on windows
      :show_console,

      # conditional close console window on windows
      :close_console,
    ]
    self.singleton_class.instance_eval do
      attr_reader(*options)
    end

    Accessor = Module.new do |mod|
      options.each do |name|
        mod.define_method name do
          Yamatanooroti::Options.public_send(name)
        end
      end
    end

    module WindowsTerminal
      ALIAS = {
        stable: :"1.21",
        preview: :"1.22preview"
      }
      RELEASES = {
        "1.22preview": {
          url: "https://github.com/microsoft/terminal/releases/download/v1.22.2702.0/Microsoft.WindowsTerminalPreview_1.22.2702.0_x64.zip",
          sha256: "CE8EED54D120775F31E3572A76EF5AE461B9E2D8887AB5DFF2F1859E24F4CE0B"
        },
        "1.21": {
          url: "https://github.com/microsoft/terminal/releases/download/v1.21.2701.0/Microsoft.WindowsTerminal_1.21.2701.0_x64.zip",
          sha256: "2F712872ED7F552763F3776EA7A823C9E7413CFD5EC65B88E95162E93ACEF899"
        },
        "1.21preview": {
          url: "https://github.com/microsoft/terminal/releases/download/v1.21.1772.0/Microsoft.WindowsTerminalPreview_1.21.1772.0_x64.zip",
          sha256: "6AA37175E2B09170829A39DAF3357D4B88A3965C3C529A45B1B0781B8F3425F0"
        },
        "1.20": {
          url: "https://github.com/microsoft/terminal/releases/download/v1.20.11781.0/Microsoft.WindowsTerminal_1.20.11781.0_x64.zip",
          sha256: "B7A6046903CE33D75250DA7E40AD2929E51703AB66E9C3A0B02A839C2E868FEC"
        },
        "1.19": {
          url: "https://github.com/microsoft/terminal/releases/download/v1.19.11213.0/Microsoft.WindowsTerminal_1.19.11213.0_x64.zip",
          sha256: "E32D7E72F8490AD94174708BB0B420E1EF4467B92F442D40DFAFDF42202A16A7"
        },
        "1.18": {
          url: "https://github.com/microsoft/terminal/releases/download/v1.18.10301.0/Microsoft.WindowsTerminal_1.18.10301.0_x64.zip",
          sha256: "38B0E38B545D9C61F1B4214EA3EC6117C0EC348FEB18476D04ECEFB4D7DA723D"
        },
        # v1.17 : the first windows terminal supports portable mode
        "1.17": {
          url: "https://github.com/microsoft/terminal/releases/download/v1.17.11461.0/Microsoft.WindowsTerminal_1.17.11461.0_x64.zip",
          sha256: "F2B1539649D17752888D7944F97D6372F8D48EB1CEB024501DF8D8E9D3352F25"
        },
      }

      def self.interpret(name)
        if ALIAS.has_key?(name)
          name = ALIAS[name]
        end
        if RELEASES.has_key?(name)
          return name.to_s
        elsif name == :canary
          return name
        end
        raise "bug! #{name} is unknows"
      end
    end

    CONHOST_TYPES = [:conhost, :"legacy-conhost"]
    TERMINAL_TYPES = [:stable, :preview, :canary]
    TERMINAL_VERSIONS = WindowsTerminal::RELEASES.keys
    CLOSE_WHEN = [:always, :pass, :never]

    ::Test::Unit::AutoRunner.setup_option do |autorunner, o|
      @default_wait = 0.01
      @default_timeout = 2.0
      @windows = Yamatanooroti.win? ? :conhost : nil
      @conhost = true
      @terminal = false
      @terminal_workdir = nil
      @show_console = nil
      @close_console = :always

      o.on_tail("yamatanooroti options")
      o.on_tail("--wait=#{@default_wait}", Float,
                "Specify yamatanooroti wait time in seconds.") do |seconds|
        @default_wait = seconds
      end

      o.on_tail("--timeout=#{@default_timeout}", Float,
                "Specify yamatanooroti timeout in seconds.") do |seconds|
        @default_timeout = seconds
      end

      o.on_tail("windows specific yamatanooroti options")

      o.on_tail("--windows=TYPE", CONHOST_TYPES + TERMINAL_TYPES + TERMINAL_VERSIONS,
                "Specify console type",
                "(#{autorunner.keyword_display(CONHOST_TYPES + TERMINAL_TYPES)})",
                "(#{TERMINAL_VERSIONS.sort.join(", ")})") do |type|
        @conhost = CONHOST_TYPES.include?(type)
        @terminal = !@conhost
        @windows =  @conhost ? type : WindowsTerminal.interpret(type)
      end

      o.on_tail("--wt-dir=DIR", String,
                "Specify Windows Terminal working dir.",
                "Automatically determined if not specified.",
                "DIR is treaded permanent if specified so download files are remains there.") do |dir|
        @terminal_workdir = dir
      end

      o.on_tail("--[no-]show-console",
                "Show test ongoing console.") do |show|
        @show_console = show
      end

      o.on_tail("--[no-]close-console[=COND]", CLOSE_WHEN,
                "Close test target console when COND met",
                "(#{autorunner.keyword_display(CLOSE_WHEN)})") do |cond|
        @close_console = (cond.nil? ? :always : cond) || :never
      end
    end
  end

  def self.options
    Options
  end
end
