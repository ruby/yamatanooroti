class Yamatanooroti::WindowsTerminalTerm
  include Yamatanooroti::WindowsTermMixin

  @@count = 0

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

  private def invoke_wt_process(command, marker, timeout)
    spawn(command)
    # wait for create console process complete
    wait_until = Time.now + timeout + 3 # 2sec timeout seems to be too short
    marker_pid = loop do
      pid = pid_from_imagename(marker)
      break pid if pid
      raise "Windows Terminal marker process detection failed." if wait_until < Time.now
      sleep @wait
    end
    @console_process_id = marker_pid

    # wait for console startup complete
    8.times do |n|
      break if attach_terminal { true }
      sleep 0.01 * 2**n
    end

    keeper_pid = attach_terminal do
      spawn(CONSOLE_KEEPING_COMMAND)
    end
    @console_process_id = keeper_pid

    # wait for console keeping process startup complete
    8.times do |n|
      break if attach_terminal { true }
      sleep 0.01 * 2**n
    end

    Process.kill(:KILL, marker_pid)
    return keeper_pid
  end

  def new_wt(rows, cols, timeout)
    marker_command = CONSOLE_MARKING_COMMAND

    @wt_id = "yamaoro#{Process.pid}##{@@count}"
    @@count += 1
    command = "#{Yamatanooroti::WindowsConsoleSettings.wt_exe} -w #{@wt_id} --size #{cols},#{rows} nt --title #{@wt_id} #{marker_command}"

    return invoke_wt_process(command, marker_command.split(" ").first, timeout)
  end

  def split_pane(div = 0.5, timeout)
    marker_command = CONSOLE_MARKING_COMMAND

    command = "#{Yamatanooroti::WindowsConsoleSettings.wt_exe}  -w #{@wt_id} sp -V --title #{@wt_id} -s #{div} #{marker_command}"
    return invoke_wt_process(command, marker_command.split(" ").first, timeout)
  end

  def close_pane
    Process.kill(:KILL, @console_process_id)
    @console_process_id = @terminal_process_id
  end

  @@minimum_width = nil
  @@div_to_width = {}
  @@width_to_div = {}

  def self.setup_console(height, width, wait, timeout)
    if @@minimum_width.nil? || @@minimum_width <= width
      wt = self.new(height, width, wait, timeout)
    end
    if wt
      size = wt.get_size
      if size == [height, width]
        return wt 
      else
        @@minimum_width = size[1]
        wt.close_console
      end
    end
    min_w = @@minimum_width
    expanded_size = min_w + 30
    wt = self.new(height, expanded_size, wait, timeout)
    div = @@width_to_div[width]
    div ||= (width * 98 + (min_w - width) * 9) / (expanded_size - 5)
    loop do
      w = dw = @@div_to_width[div]
      unless w
        wt.split_pane(div/100.0, timeout)
        size = wt.get_size
        w = @@div_to_width[div] = size[1]
      end
      if w == width
        wt.split_pane(div/100.0, timeout) if dw
        @@width_to_div[width] = div
        return wt
      else
        unless dw
          wt.close_pane
          sleep Yamatanooroti::WindowsConsoleSettings.wt_wait
        end
        if w > width
          div -= 1
          if div <= 0
            raise "Could not set Windows Terminal to size #{[height, width]}"
          end
        else
          div += 1
          if div >= 100
            raise "Could not set Windows Terminal to size #{[height, width]}"
          end
        end
      end
    end
  end

  def initialize(height, width, wait, timeout)
    @wait = wait
    @result = nil
    @codepage_success_p = nil

    @terminal_process_id = new_wt(height, width, timeout)
  end

  def close
    if @target && !@target.closed?
      @target.close
    end
    @result ||= retrieve_screen if !DL.interrupted? && @console_process_id
  end

  def close_console
    if @target && !@target.closed?
      @target.close
    end
    begin
      Process.kill("KILL", @console_process_id) if @console_process_id
    rescue Errno::ESRCH # No such process
    ensure
      begin
        if @console_process_id != @terminal_process_id
          Process.kill("KILL", @terminal_process_id)
        end
      rescue Errno::ESRCH # No such process
      end
      @console_process_id = @terminal_process_id = nil
    end
  end
end
