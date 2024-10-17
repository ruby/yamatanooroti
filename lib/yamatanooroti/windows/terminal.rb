class Yamatanooroti::WindowsTerminalTerm
  include Yamatanooroti::WindowsTermMixin

  @@count = 0
  @@cradle = {}

  def call_spawn(command)
    pid = spawn(command)
    if t = Process.detach(pid)
      @@cradle[pid] = t
    end
    pid
  end

  def kill_and_wait(pid)
    return unless pid
    t = @@cradle[pid]
    begin
      Process.kill(:KILL, pid)
    rescue Errno::ESRCH # No such process
    end
    if t
      if t.join(@timeout) == nil
        puts "Caution: process #{pid} does not terminate in #{@timeout} seconds."
      end
      @@cradle.delete(pid)
    end
  end

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

  private def with_timeout(timeout_message, timeout = @timeout, &block)
    wait_until = Time.now + timeout
    loop do
      result = block.call
      break result if result
      raise timeout_message if wait_until < Time.now
      sleep @wait
    end
  end

  private def invoke_wt_process(command, marker)
    DL.create_console(command)
    # default timeout seems to be too short
    begin
      marker_pid = with_timeout("Windows Terminal marker process detection failed.", @timeout + 5) do
        pid_from_imagename(marker)
      end
    rescue => e
      puts `tasklist /FI "SESSION ge 0"`
      raise e
    end
    @console_process_id = marker_pid

    # wait for console startup complete
    with_timeout("Console process startup timed out.") do
      attach_terminal { true }
    end

    keeper_pid = attach_terminal do
      call_spawn(CONSOLE_KEEPING_COMMAND)
    end
    @console_process_id = keeper_pid

    # wait for console keeping process startup complete
    with_timeout("Console process startup timed out.") do
      attach_terminal { true }
    end

    kill_and_wait(marker_pid)
    return keeper_pid
  end

  def new_wt(rows, cols)
    marker_command = CONSOLE_MARKING_COMMAND

    @wt_id = "yamaoro#{Process.pid}##{@@count}"
    @@count += 1
    command = "#{Yamatanooroti::WindowsConsoleSettings.wt_exe} -w #{@wt_id} --size #{cols},#{rows} nt --title #{@wt_id} #{marker_command}"

    return invoke_wt_process(command, marker_command.split(" ").first)
  end

  def split_pane(div = 0.5)
    marker_command = CONSOLE_MARKING_COMMAND

    command = "#{Yamatanooroti::WindowsConsoleSettings.wt_exe}  -w #{@wt_id} sp -V --title #{@wt_id} -s #{div} #{marker_command}; swap-pane previous"
    return invoke_wt_process(command, marker_command.split(" ").first)
  end

  def close_pane
    kill_and_wait(@console_process_id)
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
    #expanded_size = min_w + 30 # for default font size
    expanded_size = 101
    wt = self.new(height, expanded_size, wait, timeout)
    div = @@width_to_div[width]
    #div ||= (width * 98 + (min_w - width) * 9) / (expanded_size - 5) # for default font size
    div ||= (expanded_size - width) * 84 / expanded_size + 8
    loop do
      wt.split_pane(div/100.0)
      sleep Yamatanooroti::WindowsConsoleSettings.wt_wait
      size = wt.get_size
      w = size[1]
      @@width_to_div[w] = div
      if w == width
        return wt
      else
        wt.close_pane
        sleep Yamatanooroti::WindowsConsoleSettings.wt_wait
        if w < width
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
    @timeout = timeout
    @result = nil
    @codepage_success_p = nil

    @terminal_process_id = new_wt(height, width)
  end

  def self.diagnose_size_capability
    wt = self.new(999, 999, 0.01, 5.0)
    @@max_size = wt.get_size
    @@max_size = [[@@max_size[0], 60].min, [@@max_size[1], 200].min]
    puts @@max_size.then { "Windows Terminal maximum size: rows: #{_1}, columns: #{_2}" }
    wt.close_console
    wt = self.new(2, 2, 0.01, 5.0)
    @@min_size = wt.get_size
    puts @@min_size.then { "Windows Terminal smallest size: rows: #{_1}, columns: #{_2}" }
    wt.close_console
  end

  def close
    if @target && !@target.closed?
      @target.close
    end
    @result ||= retrieve_screen if !DL.interrupted? && @console_process_id
  end

  def close_console(passed = nil)
    if @target && !@target.closed?
      @target.close
    end
    puts get_size.then { "Windows Terminal max size: rows: #{_1}, columns: #{_2}" } if @terminal_process_id && passed == false
    kill_and_wait(@console_process_id) if @console_process_id
    kill_and_wait(@terminal_process_id) if @console_process_id != @terminal_process_id
    @console_process_id = @terminal_process_id = nil
  end
end
