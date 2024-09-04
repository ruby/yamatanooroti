require 'test/unit'
require 'vterm'
require 'pty'
require 'io/console'

module Yamatanooroti::VTermTestCaseModule
  def start_terminal(height, width, command, wait: 0.01, timeout: 2, startup_message: nil)
    @timeout = timeout
    @wait = wait
    @result = nil

    @pty_output, @pty_input, @pid = PTY.spawn('bash', '-c', %[stty rows #{height.to_s} cols #{width.to_s}; "$@"], '--', *command)

    @vterm = VTerm.new(height, width)
    @vterm.set_utf8(true)

    @screen = @vterm.screen
    @screen.reset(true)

    case startup_message
    when String
      wait_startup_message { |message| message.start_with?(startup_message) }
    when Regexp
      wait_startup_message { |message| startup_message.match?(message) }
    end
  end

  def write(str)
    sync
    str_to_write = +String.new(encoding: Encoding::ASCII_8BIT)
    str.chars.each do |c|
      byte = c.force_encoding(Encoding::ASCII_8BIT).ord
      if c.bytesize == 1 and byte.allbits?(0x80) # with Meta key
        c = (byte ^ 0x80).chr
        str_to_write << "\e"
        str_to_write << c
      else
        str_to_write << c
      end
    end
    @pty_input.write(str_to_write)
    # Write str (e.g. `exit`) to pty_input might terminate the process.
    try_sync
  end

  def close
    begin
      sync
      @pty_input.close
      sync
    rescue IOError, Errno::EIO
    end
    begin
      Process.kill('KILL', @pid)
      Process.waitpid(@pid)
    rescue Errno::ESRCH
    end
  end

  private def wait_startup_message
    wait_until = Time.now + @timeout
    chunks = +''
    loop do
      wait = wait_until - Time.now
      if wait.negative? || !@pty_output.wait_readable(wait)
        raise "Startup message didn't arrive within timeout: #{chunks.inspect}"
      end

      chunk = @pty_output.read_nonblock(65536)
      vterm_write(chunk)
      chunks << chunk
      break if yield chunks
    end
  end

  private def vterm_write(chunk)
    @vterm.write(chunk)
    @pty_input.write(@vterm.read)
    @result = nil
  end

  private def sync(wait = @wait)
    sync_until = Time.now + @timeout
    while @pty_output.wait_readable(wait)
      vterm_write(@pty_output.read_nonblock(65536))
      break if Time.now > sync_until
    end
  end

  private def try_sync(wait = @wait)
    sync(wait)
    true
  rescue IOError, Errno::EIO
    false
  end


  def result
    try_sync(0)
    @result ||= retrieve_screen
  end

  private def retrieve_screen
    result = []
    rows, cols = @vterm.size
    rows.times do |r|
      result << +''
      cols.times do |c|
        cell = @screen.cell_at(r, c)
        if cell.char # The second cell of fullwidth char will be nil.
          if cell.char.empty?
            # There will be no char to the left of the rendered area if moves
            # the cursor.
            result.last << ' '
          else
            result.last << cell.char
          end
        end
      end
      result.last.gsub!(/ *$/, '')
    end
    result
  end

  private def assert_screen_with_proc(check_proc, assert_block, convert_proc = :itself.to_proc)
    retry_until = Time.now + @timeout
    while Time.now < retry_until
      break unless try_sync

      @result ||= retrieve_screen
      break if check_proc.call(convert_proc.call(@result))
    end
    @result ||= retrieve_screen
    assert_block.call(convert_proc.call(@result))
  end

  def assert_screen(expected_lines, message = nil)
    lines_to_string = ->(lines) { lines.join("\n").sub(/\n*\z/, "\n") }
    case expected_lines
    when Array
      assert_screen_with_proc(
        ->(a) { expected_lines == a },
        ->(a) { assert_equal(expected_lines, a, message) }
      )
    when String
      assert_screen_with_proc(
        ->(a) { expected_lines == a },
        ->(a) { assert_equal(expected_lines, a, message) },
        lines_to_string
      )
    when Regexp
      assert_screen_with_proc(
        ->(a) { expected_lines.match?(a) },
        ->(a) { assert_match(expected_lines, a, message) },
        lines_to_string
      )
    end
  end
end

class Yamatanooroti::VTermTestCase < Test::Unit::TestCase
  include Yamatanooroti::VTermTestCaseModule
end
