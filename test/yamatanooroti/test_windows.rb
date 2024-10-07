require 'yamatanooroti'

class Yamatanooroti::TestWindows < Test::Unit::TestCase
  def test_load
    if Yamatanooroti.win?
      assert_nothing_raised do
        Yamatanooroti::WindowsTestCase
      end
    else
      assert_raise(LoadError) do
        Yamatanooroti::WindowsTestCase
      end
    end
  end
end

class Yamatanooroti::TestWindowsCodepage < Yamatanooroti::TestCase
  if Yamatanooroti.win?
    def test_codepage_932
      start_terminal(5, 30, ['ruby', '-e', 'puts(%Q!Encoding:#{Encoding.find(%Q[locale]).name}!)'], startup_message: 'Encoding:', codepage: 932)
      omit "codepage 932 not supported" if !codepage_success?
      assert_equal(['Encoding:Windows-31J', '', '', '', ''], result)
      close
    end

    def test_codepage_437
      start_terminal(5, 30, ['ruby', '-e', 'puts(%Q!Encoding:#{Encoding.find(%Q[locale]).name}!)'], startup_message: 'Encoding:', codepage: 437)
      omit "codepage 437 not supported" if !codepage_success?
      assert_equal(['Encoding:IBM437', '', '', '', ''], result)
      close
    end
  end
end
