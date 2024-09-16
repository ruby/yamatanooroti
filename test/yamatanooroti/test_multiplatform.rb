require 'yamatanooroti'

class Yamatanooroti::TestMultiplatform < Yamatanooroti::TestCase
  def setup
    start_terminal(5, 30, ['ruby', 'bin/simple_repl'], startup_message: 'prompt>')
  end

  def test_example
    write(":a\n")
    close
    assert_screen(['prompt> :a', '=> :a', 'prompt>', '', ''])
    assert_screen(<<~EOC)
      prompt> :a
      => :a
      prompt>
    EOC
  end

  def test_result_repeatedly
    write(":a\n")
    assert_screen(/=> :a\nprompt>/)
    assert_equal(['prompt> :a', '=> :a', 'prompt>', '', ''], result)
    write(":b\n")
    assert_screen(/=> :b\nprompt>/)
    assert_equal(['prompt> :a', '=> :a', 'prompt> :b', '=> :b', 'prompt>'], result)
    close
  end

  def test_assert_screen_retries
    write("sleep 1\n")
    assert_screen(/=> 1\nprompt>/)
    assert_equal(['prompt> sleep 1', '=> 1', 'prompt>', '', ''], result)
    close
  end

  def test_assert_screen_timeout
    write("sleep 3\n")
    assert_raise do
      assert_screen(/=> 3\nprompt>/)
    end
    close
  end

  def test_auto_wrap
    write("12345678901234567890123\n")
    close
    assert_screen(['prompt> 1234567890123456789012', '3', '=> 12345678901234567890123', 'prompt>', ''])
    assert_screen(<<~EOC)
      prompt> 1234567890123456789012
      3
      => 12345678901234567890123
      prompt>
    EOC
  end

  def test_fullwidth
    write(":あ\n")
    close
    assert_screen(/=> :あ\nprompt>/)
    assert_equal(['prompt> :あ', '=> :あ', 'prompt>', '', ''], result)
  end

  def test_two_fullwidth
    write(":あい\n")
    close
    assert_screen(/=> :あい\nprompt>/)
    assert_equal(['prompt> :あい', '=> :あい', 'prompt>', '', ''], result)
  end
end
