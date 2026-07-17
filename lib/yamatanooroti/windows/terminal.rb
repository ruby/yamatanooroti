require_relative "./wt"

class Yamatanooroti::WindowsTerminalTerm
  include Yamatanooroti::WindowsTermMixin
  Self = self

  def self.window_title
    @count = @count ? @count + 1 : 0
    "yamatanooroti##{@count}@#{Process.pid}"
  end

  def self.testcase_title(title)
    count = @iter_count&.fetch(title)
    count ||= countup_testcase_title(title)
    "#{title}##{count}@#{Process.pid}"
  end

  def self.countup_testcase_title(title)
    counter = (@iter_count ||= {})
    count = counter[title] || 0
    counter[title] = count + 1
  end

  class << self
    attr_accessor :wt, :max_size, :min_size, :split_cache_h, :split_cache_v
  end

  def self.setup_console(height, width, codepage, wait, timeout, name)
    if !Self.wt
      Self.wt = self.new(*max_size, wait, timeout, Self.window_title)
    end

    countup_testcase_title(name)
    new_tab = Self.wt.new_tab(height, width, name)
    new_tab.setup_cp(codepage) if codepage
    Self.wt
  end

  def codepage_success?
    @wt.active_tab.codepage_success?
  end

  def console_process_id
    @wt.active_tab&.console_process_id
  end

  def get_size
    (@wt.active_tab || @wt.base_tab).get_size
  end

  def initialize(height, width, wait, timeout, title = "yamatanooroti")
    check_interrupt
    @wait = wait
    @timeout = timeout
    @result = nil
    @codepage_success_p = nil
    @wrote_and_not_yet_waited = false

    @wt = Yamatanooroti::WindowsTerminal.new(height, width, title, title, wait, timeout, self)
  end

  def new_tab(height, width, name)
    @result = nil
    @codepage_success_p = nil
    @wrote_and_not_yet_waited = false
    @name = name

    @wt.new_tab(height, width, testcase_title(name))
  end

  def close_console(need_to_close = true)
    if need_to_close || DL.interrupted?
      if @target && !@target.closed?
        @target.close
      end
      @wt&.close_tab
    else
      @wt&.detach_tab
    end
  end

  def close!
    @wt&.close
    @wt = nil
  end

  def self.diagnose_size_capability
    wt = self.new(999, 999, 0.01, 5.0)
    max_size = wt.get_size
    Self.max_size = [[max_size[0], 60].min, [max_size[1], 200].min]
    puts max_size.then { |r, c| "Windows Terminal maximum size: rows: #{r}, columns: #{c}" }
    wt.close!
    #wt = self.new(2, 2, 0.01, 5.0)
    #min_size = wt.get_size
    #Self.min_size = min_size
    #puts min_size.then { |r, c| "Windows Terminal smallest size: rows: #{r}, columns: #{c}" }
    #wt.close!
    puts Self.max_size.then {|r, c|  "Use test window size: rows: #{r}, columns: #{c}" }
  end

  Test::Unit.at_exit do
    Self.wt&.close!
  end
end
