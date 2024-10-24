class Yamatanooroti::ConhostTerm
  include Yamatanooroti::WindowsTermMixin

  def self.setup_console(height, width, wait, timeout, name)
    new(height, width, wait, timeout, name)
  end

  attr_reader :console_process_id

  def initialize(height, width, wait, timeout, name)
    @wait = wait
    @timeout = timeout
    @name = name
    @result = nil
    @codepage_success_p = nil
    @wrote_and_not_yet_waited = false

    @console_process_id = DL.create_console(keeper_commandline(name), show_console_param())

    sleep 0.1 if Yamatanooroti.options.windows == :"legacy-conhost" # ad-hoc

    # wait for console startup complete
    with_timeout("Console process startup timed out.") do
      attach_terminal(open: false, exception: false) { true }
    end

    attach_terminal do |conin, conout|
      DL.set_console_window_size(conout, height, width)
    end
  end

  def close_console(need_to_close = true)
    if (need_to_close)
      if @target && !@target.closed?
        @target.close
      end
      begin
        Process.kill("KILL", @console_process_id) if @console_process_id
      rescue Errno::ESRCH # No such process
      ensure
        @console_process_id = nil
      end
    end
  end

  def close!
    close_console(!Yamatanooroti.options.show_console)
  end
end
