require 'stringio'

module Yamatanooroti::WindowsTermMixin
  DL = Yamatanooroti::WindowsDefinition

  CONSOLE_KEEPING_COMMAND = %q[ruby.exe --disable=gems -e sleep]
  CONSOLE_MARKING_COMMAND = %q[findstr.exe yamatanooroti]

  private def attach_terminal(open = true)
    stderr = $stderr
    $stderr = StringIO.new

    conin = conout = nil
    DL.free_console
    # this can be fail while new process is starting
    r = DL.attach_console(@console_process_id, maybe_fail: true)
    return nil unless r

    if open
      conin = DL.create_console_file_handle("conin$")
      return nil if conin == DL::INVALID_HANDLE_VALUE

      conout = DL.create_console_file_handle("conout$")
      return nil if conout == DL::INVALID_HANDLE_VALUE
    end

    yield(conin, conout)
  rescue => evar
  ensure
    DL.close_handle(conin) if conin && conin != DL::INVALID_HANDLE_VALUE
    DL.close_handle(conout) if conout && conout != DL::INVALID_HANDLE_VALUE
    DL.free_console
    DL.attach_console
    stderr.write $stderr.string
    $stderr = stderr
    raise evar if evar
  end

  private def quote_command_arg(arg)
    if not arg.match?(/[ \t"<>|()]/)
      # No quotation needed.
      return arg
    end

    if not arg.match?(/["\\]/)
      # No embedded double quotes or backlashes, so I can just wrap quote
      # marks around the whole thing.
      return %{"#{arg}"}
    end

    quote_hit = true
    result = +'"'
    arg.chars.reverse.each do |c|
      result << c
      if quote_hit and c == '\\'
        result << '\\'
      elsif c == '"'
        quote_hit = true
        result << '\\'
      else
        quote_hit = false
      end
    end
    result << '"'
    result.reverse
  end

  class SubProcess
    def initialize(command)
      @errin, err = IO.pipe
      @pid = spawn(command, {in: ["conin$", File::RDWR | File::BINARY], out: ["conout$", File::RDWR | File::BINARY], err: err})
      @mon = Process.detach(@pid)
      err.close
      @closed = false
      @status = nil
      @q = Thread::Queue.new
      @t = Thread.new do
        begin
          err = @errin.gets
          @q << err if err
        rescue IOError
          # target process already terminated
          next
        end
      end
    end

    def close
      unless closed?
        begin
          Process.kill("KILL", @pid)
        rescue Errno::ESRCH # No such process
        end
        @status = @mon.join.value
        sync
        @errin.close
      end
    end

    def closed?
      !@mon.alive?
    end

    private def consume(buffer)
      while !@q.empty?
        buffer << @q.shift
      end
    end

    def sync
      buffer = ""
      if closed?
        if !@errin.closed?
          @t.kill
          @t.join
          consume(buffer)
          rest = "".b
          while ((str = @errin.read_nonblock(1024, exception: false)).is_a?(String)) do
            rest << str
          end
          buffer << rest.force_encoding(Encoding.default_external) << "\n" if rest != ""
        end
      else
        consume(buffer)
      end
      $stderr.write buffer if buffer != ""
    end
  end

  def launch(command)
    attach_terminal do
      @target = SubProcess.new(command.map{ |c| quote_command_arg(c) }.join(' '))
    end
  end

  def setup_cp(cp)
    @codepage_success_p = attach_terminal { system("chcp #{Integer(cp)} > NUL") }
  end

  def codepage_success?
    @codepage_success_p
  end

  def write(str)
    codes = str.chars.map do |c|
      c = "\r" if c == "\n"
      byte = c.getbyte(0)
      if c.bytesize == 1 and byte.allbits?(0x80) # with Meta key
        [-(byte ^ 0x80)]
      else
        DL.mb2wc(c).unpack("S*")
      end
    end.flatten
    record = DL::INPUT_RECORD_WITH_KEY_EVENT.malloc(DL::FREE)
    records = codes.reduce("".b) do |records, code|
      DL.set_input_record(record, code)
      record.bKeyDown = 1
      records << record.to_ptr.to_str
      record.bKeyDown = 0
      records << record.to_ptr.to_str
    end
    attach_terminal do |conin, conout|
      DL.write_console_input(conin, records, codes.size * 2)
      loop do
        sleep @wait
        n = DL.get_number_of_console_input_events(conin)
        break if n <= 1  # maybe keyup event still be there
        break if n.nil?
        @target.sync
        break if @target.closed?
      end
    end
  end

  def retrieve_screen(top_of_buffer: false)
    return @result if @result
    @target.sync
    top, bottom, width = attach_terminal do |conin, conout|
      csbi = DL.get_console_screen_buffer_info(conout)
      if top_of_buffer
        [0, csbi.Bottom, csbi.Right - csbi.Left + 1]
      else
        [csbi.Top, csbi.Bottom, csbi.Right - csbi.Left + 1]
      end
    end

    lines = attach_terminal do |conin, conout|
      (top..bottom).map do |y|
        DL.read_console_output(conout, y, width) || ""
      end
    end
    lines
  end

  def result
    @result || retrieve_screen
  end
end
