require 'test/unit'
require_relative 'windows/windows-definition'
require_relative 'windows/windows-setup'
require_relative 'windows/windows'
require_relative 'windows/conhost'
require_relative 'windows/terminal'

module Yamatanooroti::WindowsTestCaseModule
  def write(str)
    @terminal.write(str)
  end

  def close
    @result = @terminal.close
  end

  def result
    @terminal.result
  end

  def codepage_success?
    @terminal.codepage_success?
  end

  def identify
    @terminal.identify
  end

  def start_terminal(height, width, command, wait: nil, timeout: nil, startup_message: nil, codepage: nil)
    @timeout = timeout || Yamatanooroti.options.default_timeout
    @startup_timeout = @timeout + 2
    @wait = wait || Yamatanooroti.options.default_wait
    @result = nil
    if @terminal
      if !Yamatanooroti.options.show_console || Yamatanooroti.options.close_console != :never
        @terminal.close_console
      end
    end
    if Yamatanooroti.options.conhost
      @terminal = Yamatanooroti::ConhostTerm.setup_console(height, width, @wait, @timeout, local_name)
    else
      @terminal = Yamatanooroti::WindowsTerminalTerm.setup_console(height, width, @wait, @timeout, local_name)
    end
    @terminal.setup_cp(codepage) if codepage
    @terminal.launch(command)

    case startup_message
    when String
      wait_startup_message { |message| message.start_with?(startup_message.chars.each_slice(width).map { |l| l.join.rstrip }.join("\n")) }
    when Regexp
      wait_startup_message { |message| startup_message.match?(message) }
    end
  end

  private def wait_startup_message
    wait_until = Time.now + @startup_timeout
    chunks = +''
    loop do
      wait = wait_until - Time.now
      if wait.negative?
        raise "Startup message didn't arrive within timeout: #{chunks.inspect}"
      end

      chunks = @terminal.retrieve_screen.join("\n").sub(/\n*\z/, "\n")
      break if yield chunks
      sleep @wait
    end
  end

  private def retryable_screen_assertion_with_proc(check_proc, assert_proc, convert_proc = :itself.to_proc)
    retry_until = Time.now + @timeout
    screen = if @result
      convert_proc.call(@result)
    else
      loop do
        screen = convert_proc.call(@terminal.retrieve_screen)
        break screen if Time.now >= retry_until
        break screen if check_proc.call(screen)
        sleep @wait
      end
    end
    @terminal.clear_need_wait_flag
    assert_proc.call(screen)
  end

  def assert_screen(expected_lines, message = nil)
    lines_to_string = ->(lines) { lines.join("\n").sub(/\n*\z/, "\n") }
    case expected_lines
    when Array
      retryable_screen_assertion_with_proc(
        ->(actual) { expected_lines == actual },
        ->(actual) { assert_equal(expected_lines, actual, message) }
      )
    when String
      retryable_screen_assertion_with_proc(
        ->(actual) { expected_lines == actual },
        ->(actual) { assert_equal(expected_lines, actual, message) },
        lines_to_string
      )
    when Regexp
      retryable_screen_assertion_with_proc(
        ->(actual) { expected_lines.match?(actual) },
        ->(actual) { assert_match(expected_lines, actual, message) },
        lines_to_string
      )
    end
  end

  def self.included(cls)
    cls.instance_exec do
      teardown do
        @terminal&.close_console(
          !Yamatanooroti.options.show_console ||
           Yamatanooroti.options.close_console == :always || 
           Yamatanooroti.options.close_console == :pass && passed?
        )
      end
    end
  end
end

class Yamatanooroti::WindowsTestCase < Test::Unit::TestCase
  include Yamatanooroti::WindowsTestCaseModule
end
