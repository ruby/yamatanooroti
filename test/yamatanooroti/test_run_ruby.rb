require 'yamatanooroti'
require 'tmpdir'

class Yamatanooroti::TestRunRuby < Yamatanooroti::TestCase
  def teardown
    close
  end

  def test_winsize
    start_terminal(5, 30, ['ruby', '-rio/console', '-e', 'puts(IO.console.winsize.inspect)'])
    assert_screen(<<~EOC)
      [5, 30]
    EOC
    close
  end

  def test_wait_for_startup_message
    code = 'sleep 1; print "prompt>"; s = gets; sleep 1; puts s.upcase'
    start_terminal(5, 30, ['ruby', '-e', code], startup_message: 'prompt>')
    assert_equal(['prompt>', '', '', '', ''], result)
    write "hello\n"
    assert_screen(<<~EOC)
      prompt>hello
      HELLO
    EOC
  end

  def test_move_cursor_and_render
    start_terminal(5, 30, ['ruby', '-rio/console', '-e', 'STDOUT.puts(?A);STDOUT.goto(2,2);STDOUT.puts(?B)'])
    assert_screen(['A', '', '  B', '', ''])
    assert_equal(['A', '', '  B', '', ''], result)
  end

  def test_meta_key
    get_into_tmpdir
    if !Yamatanooroti.win? || (RUBY_VERSION > '2.6.99' && RUBY_VERSION < '3.4.0')
      command = ['ruby', '-rreline', '-e', 'Reline.readline(%{>>>})']
    else
      command = ['bundle', 'exec', 'ruby', '-e', 'require "reline"; Reline.readline(%{>>>})']
      # older ruby inboxed reline (0.1.5) has a windows specific bug. use newer reline
    end
    start_terminal(5, 30, command, startup_message: />{3}/)
    write('aaa ccc')
    write("\M-b")
    write('bbb ')
    assert_screen(<<~EOC)
      >>>aaa bbb ccc
    EOC
  ensure
    get_out_from_tmpdir
  end

  def test_assert_screen_takes_a_message_when_failed
    start_terminal(5, 30, ['ruby', '-e', 'puts "aaa"'])
    assert_raise_with_message Test::Unit::AssertionFailedError, /\Amessage when failed/ do
      assert_screen(<<~EOC, 'message when failed')
        bbb
      EOC
    end
  end

  private

  def get_into_tmpdir
    @pwd = Dir.pwd
    suffix = '%010d' % Random.rand(0..65535)
    @tmpdir = File.join(File.expand_path(Dir.tmpdir), "test_yamatanooroti_#{$$}_#{suffix}")
    begin
      Dir.mkdir(@tmpdir)
    rescue Errno::EEXIST
      FileUtils.rm_rf(@tmpdir)
      Dir.mkdir(@tmpdir)
    end
    @inputrc_backup = ENV['INPUTRC']
    @inputrc_file = ENV['INPUTRC'] = File.join(@tmpdir, 'temporary_inputrc')
    File.unlink(@inputrc_file) if File.exist?(@inputrc_file)
  end

  def get_out_from_tmpdir
    FileUtils.rm_rf(@tmpdir)
    ENV['INPUTRC'] = @inputrc_backup
    ENV.delete('RELINE_TEST_PROMPT') if ENV['RELINE_TEST_PROMPT']
  end
end
