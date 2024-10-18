class Yamatanooroti::ConhostTerm
  include Yamatanooroti::WindowsTermMixin

  def self.setup_console(height, width, wait, name)
    new(height, width, wait, name)
  end

  def initialize(height, width, wait, name)
    @wait = wait
    @result = nil
    @codepage_success_p = nil

    @console_process_id = DL.create_console(CONSOLE_KEEPING_COMMAND.sub("NAME", name))

    # wait for console startup complete
    8.times do |n|
      break if attach_terminal { true }
      sleep 0.01 * 2**n
    end

    attach_terminal do |conin, conout|
      DL.set_console_window_size(conout, height, width)
    end
  end

  def close
    if @target && !@target.closed?
      @target.close
    end
    @result ||= retrieve_screen if !DL.interrupted? && @console_process_id
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
end
