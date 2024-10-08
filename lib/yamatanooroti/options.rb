class Yamatanooroti
  module Options
    options = [:default_wait, :default_timeout, :windows, :show_console, :close_console]
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

    @default_wait = 0.01
    @default_timeout = 2.0
    @show_console = false
    @close_console = :always

    CONSOLE_TYPES = [:conhost, :"legacy-conhost"]
    CLOSE_WHEN = [:always, :pass, :never]

    ::Test::Unit::AutoRunner.setup_option do |autorunner, o|

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

      o.on_tail("--windows=TYPE", CONSOLE_TYPES,
                "Specify console type",
                "(#{autorunner.keyword_display(CONSOLE_TYPES)})") do |type|
        @windows = type
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
