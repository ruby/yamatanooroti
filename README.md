# Yamatanooroti

Yamatanooroti is a multi-platform real(?) terminal testing framework.

Supporting envronments:

- vterm gem
- Windows command prompt

## Usage

You can test the executed result and its rendering on the automatically detected environment that you have at the time, by code below:

```ruby
require 'yamatanooroti'

class MyTest < Yamatanooroti::TestCase
  def setup
    start_terminal(5, 30, ['irb', '-f', '--multiline'])
  end

  def teardown
  end

  def test_example
    write(":a\n")
    close
    assert_screen(['irb(main):001:0> :a', '=> :a', 'irb(main):002:0>', '', ''])
  end
end
```

This code detects some real(?) terminal environments:

- vterm gem (you should install beforehand)
- Windows (you should run on command prompt)

If any real(?) terminal environments not found, it will fail with a message:

```
$ rake
Traceback (most recent call last):
        (snip traceback)
/path/to/yamatanooroti/lib/yamatanooroti.rb:71:in `inherited': Any real(?) terminal environments not found. (LoadError)
Supporting real(?) terminals:
- vterm gem
- Windows
rake aborted!
Command failed with status (1)

Tasks: TOP => default => test
(See full trace by running task with --trace)
```

### Advanced Usage

If you want to specify vterm environment that needs vterm gem, you can use `Yamatanooroti::VTermTestCase`:

```ruby
require 'yamatanooroti'

class MyTest < Yamatanooroti::VTermTestCase
  def setup
    start_terminal(5, 30, ['irb', '-f', '--multiline'])
  end

  def teardown
  end

  def test_example
    write(":a\n")
    close
    assert_screen(['irb(main):001:0> :a', '=> :a', 'irb(main):002:0>', '', ''])
  end
end
```

If you haven't installed vterm gem, this code will fail with a message <q>You need vterm gem for Yamatanooroti::VTermTestCase (LoadError)</q>.

Likewise, you can specify Windows command prompt test by `Yamatanooroti::WindowsTestCase`.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
