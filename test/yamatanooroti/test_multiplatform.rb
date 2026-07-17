require 'yamatanooroti'

class Yamatanooroti::TestMultiplatform < Yamatanooroti::TestCase
  def setup
    start_terminal(5, 30, ['ruby', 'bin/simple_repl'], startup_message: 'prompt>')
  end

  def teardown
    close
  end

  def test_example
    write(":a\n")
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
  end

  def test_assert_screen_retries
    write("sleep 1 && 1\n")
    assert_screen(/=> 1\nprompt>/)
    assert_equal(['prompt> sleep 1 && 1', '=> 1', 'prompt>', '', ''], result)
  end

  def test_assert_screen_timeout
    write("sleep 3 && 3\n")
    assert_raise do
      assert_screen(/=> 3\nprompt>/)
    end
  end

  def test_auto_wrap
    write("12345678901234567890123\n")
    assert_screen(['prompt> 1234567890123456789012', '3', '=> 12345678901234567890123', 'prompt>', ''])
    assert_screen(<<~EOC)
      prompt> 1234567890123456789012
      3
      => 12345678901234567890123
      prompt>
    EOC
  end
end

class Yamatanooroti::TestMultiplatformMultiByte < Yamatanooroti::TestCase
  def setup
    if Yamatanooroti.win?
      start_terminal(5, 30, ['ruby', 'bin/simple_repl'], startup_message: 'prompt>', codepage: 932)
    else
      start_terminal(5, 30, ['ruby', 'bin/simple_repl'], startup_message: 'prompt>')
    end
  end

  def test_fullwidth
    omit "multibyte char not supported by env" if Yamatanooroti.win? and !codepage_success?
    write(":あ\n")
    assert_screen(/=> :あ\nprompt>/)
    assert_equal(['prompt> :あ', '=> :あ', 'prompt>', '', ''], result)
  end

  def test_two_fullwidth
    omit "multibyte char not supported by env" if Yamatanooroti.win? and !codepage_success?
    write(":あい\n")
    assert_screen(/=> :あい\nprompt>/)
    assert_equal(['prompt> :あい', '=> :あい', 'prompt>', '', ''], result)
  end
end
