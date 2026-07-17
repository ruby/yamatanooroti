require 'fiddle/import'
require 'fiddle/types'
class Yamatanooroti; end

module Yamatanooroti::WindowsDefinition
  extend Fiddle::Importer
  dlload 'kernel32.dll', 'user32.dll'
  include Fiddle::Win32Types

  FREE = Fiddle::Function.new(Fiddle::RUBY_FREE, [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)

  typealias 'SHORT', 'short'
  typealias 'HWND', 'HANDLE'
  typealias 'LPVOID', 'void*'
  typealias 'LPWSTR', 'void*'
  typealias 'LPBYTE', 'void*'
  typealias 'LPCWSTR', 'void*'
  typealias 'LPCVOID', 'void*'
  typealias 'LPDWORD', 'void*'
  typealias 'WCHAR', 'unsigned short'
  typealias 'LPCWCH', 'void*'
  typealias 'LPSTR', 'void*'
  typealias 'LPCCH', 'void*'
  typealias 'LPBOOL', 'void*'
  typealias 'PULONG', 'ULONG*'
  typealias 'LONG', 'int'
  typealias 'HLOCAL', 'HANDLE'

  Fiddle::SIZEOF_DWORD = Fiddle::SIZEOF_LONG
  Fiddle::SIZEOF_WORD = Fiddle::SIZEOF_SHORT
  Fiddle::SIZEOF_ULONG = Fiddle::SIZEOF_LONG if !Fiddle.const_defined?(:SIZEOF_ULONG)

  COORD = struct [
    'SHORT X',
    'SHORT Y'
  ]
  typealias 'COORD', 'DWORD32'

  SMALL_RECT = struct [
    'SHORT Left',
    'SHORT Top',
    'SHORT Right',
    'SHORT Bottom'
  ]
  typealias 'PSMALL_RECT', 'SMALL_RECT*'

  CONSOLE_SCREEN_BUFFER_INFO = struct [
    'SHORT dwSize_X', 'SHORT dwSize_Y', # 'COORD dwSize',
    'SHORT dwCursorPosition_X', 'SHORT dwCursorPosition_Y', #'COORD dwCursorPosition',
    'WORD wAttributes',
    'SHORT Left', 'SHORT Top', 'SHORT Right', 'SHORT Bottom', # 'SMALL_RECT srWindow',
    'SHORT MaxWidth', 'SHORT MaxHeight' # 'COORD dwMaximumWindowSize'
  ]
  typealias 'PCONSOLE_SCREEN_BUFFER_INFO', 'CONSOLE_SCREEN_BUFFER_INFO*'

  typealias 'COLORREF', 'DWORD'
  CONSOLE_SCREEN_BUFFER_INFOEX = struct [
    'ULONG cbSize',
    'SHORT dwSize_X', 'SHORT dwSize_Y', # 'COORD dwSize',
    'SHORT dwCursorPosition_X', 'SHORT dwCursorPosition_Y', #'COORD dwCursorPosition',
    'WORD wAttributes',
    'SHORT Left', 'SHORT Top', 'SHORT Right', 'SHORT Bottom', # 'SMALL_RECT srWindow',
    'SHORT MaxWidth', 'SHORT MaxHeight', # 'COORD dwMaximumWindowSize',
    'BOOL bFullScreenSupported',
    'COLORREF ColorTable[16]'
  ]
  typealias 'PCONSOLE_SCREEN_BUFFER_INFOEX', 'CONSOLE_SCREEN_BUFFER_INFOEX*'

  SECURITY_ATTRIBUTES = struct [
    'DWORD nLength',
    'LPVOID lpSecurityDescriptor',
    'BOOL bInheritHandle'
  ]
  typealias 'LPSECURITY_ATTRIBUTES', 'SECURITY_ATTRIBUTES*'

  STARTUPINFOW = struct [
    'DWORD cb',
    'LPWSTR lpReserved',
    'LPWSTR lpDesktop',
    'LPWSTR lpTitle',
    'DWORD dwX',
    'DWORD dwY',
    'DWORD dwXSize',
    'DWORD dwYSize',
    'DWORD dwXCountChars',
    'DWORD dwYCountChars',
    'DWORD dwFillAttribute',
    'DWORD dwFlags',
    'WORD wShowWindow',
    'WORD cbReserved2',
    'LPBYTE lpReserved2',
    'HANDLE hStdInput',
    'HANDLE hStdOutput',
    'HANDLE hStdError'
  ]
  typealias 'LPSTARTUPINFOW', 'STARTUPINFOW*'

  PROCESS_INFORMATION = struct [
    'HANDLE hProcess',
    'HANDLE hThread',
    'DWORD  dwProcessId',
    'DWORD  dwThreadId'
  ]
  typealias 'LPPROCESS_INFORMATION', 'PROCESS_INFORMATION*'

  INPUT_RECORD_WITH_KEY_EVENT = struct [
    'WORD EventType',
    'BOOL bKeyDown',
    'WORD wRepeatCount',
    'WORD wVirtualKeyCode',
    'WORD wVirtualScanCode',
    'WCHAR UnicodeChar',
    ## union 'CHAR  AsciiChar',
    'DWORD dwControlKeyState'
  ]

  STD_INPUT_HANDLE = -10
  STD_OUTPUT_HANDLE = -11
  STD_ERROR_HANDLE = -12

  STARTF_USESHOWWINDOW = 1
  CREATE_NEW_CONSOLE = 0x10
  CREATE_NEW_PROCESS_GROUP = 0x200
  CREATE_UNICODE_ENVIRONMENT = 0x400
  CREATE_NO_WINDOW = 0x08000000
  ATTACH_PARENT_PROCESS = -1
  KEY_EVENT = 0x0001
  SW_HIDE = 0
  SW_SHOWNORMAL = 1
  SW_SHOWNOACTIVE = 4
  SW_SHOWMINNOACTIVE = 7
  SW_SHOWNA = 8
  LEFT_ALT_PRESSED = 0x0002
  ENABLE_PROCESSED_INPUT = 0x0001
  ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004

  # HANDLE GetStdHandle(DWORD nStdHandle);
  extern 'HANDLE GetStdHandle(DWORD);', :stdcall
  # BOOL CloseHandle(HANDLE hObject);
  extern 'BOOL CloseHandle(HANDLE);', :stdcall

  # BOOL FreeConsole(void);
  extern 'BOOL FreeConsole(void);', :stdcall
  # BOOL AttachConsole(DWORD dwProcessId);
  extern 'BOOL AttachConsole(DWORD);', :stdcall
  # HWND WINAPI GetConsoleWindow(void);
  extern 'HWND GetConsoleWindow(void);', :stdcall
  # BOOL WINAPI SetConsoleWindowInfo(HANDLE hConsoleOutput, BOOL bAbsolute, const SMALL_RECT *lpConsoleWindow);
  extern 'BOOL SetConsoleWindowInfo(HANDLE, BOOL, PSMALL_RECT);', :stdcall
  # BOOL WriteConsoleInputW(HANDLE hConsoleInput, const INPUT_RECORD *lpBuffer, DWORD nLength, LPDWORD lpNumberOfEventsWritten);
  extern 'BOOL WriteConsoleInputW(HANDLE, const INPUT_RECORD*, DWORD, LPDWORD);', :stdcall
  # SHORT VkKeyScanW(WCHAR ch);
  extern 'SHORT VkKeyScanW(WCHAR);', :stdcall
  # UINT MapVirtualKeyW(UINT uCode, UINT uMapType);
  extern 'UINT MapVirtualKeyW(UINT, UINT);', :stdcall
  # BOOL GetNumberOfConsoleInputEvents(HANDLE  hConsoleInput, LPDWORD lpcNumberOfEvents);
  extern 'BOOL GetNumberOfConsoleInputEvents(HANDLE  hConsoleInput, LPDWORD lpcNumberOfEvents);', :stdcall
  # BOOL WINAPI ReadConsoleOutputCharacterW(HANDLE hConsoleOutput, LPWSTR lpCharacter, DWORD nLength, COORD dwReadCoord, LPDWORD lpNumberOfCharsRead);
  extern 'BOOL ReadConsoleOutputCharacterW(HANDLE, LPWSTR, DWORD, COORD, LPDWORD);', :stdcall
  # BOOL WINAPI GetConsoleScreenBufferInfo(HANDLE hConsoleOutput, PCONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo);
  extern 'BOOL GetConsoleScreenBufferInfo(HANDLE, PCONSOLE_SCREEN_BUFFER_INFO);', :stdcall
  # BOOL WINAPI GetConsoleScreenBufferInfoEx(HANDLE hConsoleOutput, PCONSOLE_SCREEN_BUFFER_INFOEX lpConsoleScreenBufferInfoEx);
  extern 'BOOL GetConsoleScreenBufferInfoEx(HANDLE, PCONSOLE_SCREEN_BUFFER_INFOEX);', :stdcall
  # BOOL WINAPI SetConsoleScreenBufferInfoEx(HANDLE hConsoleOutput, PCONSOLE_SCREEN_BUFFER_INFOEX lpConsoleScreenBufferInfoEx);
  extern 'BOOL SetConsoleScreenBufferInfoEx(HANDLE, PCONSOLE_SCREEN_BUFFER_INFOEX);', :stdcall
  # BOOL WINAPI GetConsoleMode(HANDLE hConsoleHandle, LPDWORD lpMode);
  extern 'BOOL GetConsoleMode(HANDLE, LPDWORD);', :stdcall
  # BOOL WINAPI SetConsoleMode(HANDLE hConsoleHandle, DWORD dwMode);
  extern 'BOOL SetConsoleMode(HANDLE, DWORD);', :stdcall
  # BOOL WINAPI SetConsoleCP(UINT wCodePageID);
  extern 'BOOL SetConsoleCP(UINT);', :stdcall
  # BOOL WINAPI SetConsoleOutputCP(UINT wCodePageID);
  extern 'BOOL SetConsoleOutputCP(UINT);', :stdcall
  # UINT WINAPI GetConsoleCP(void);
  extern 'UINT GetConsoleCP(void);', :stdcall
  # UINT WINAPI GetConsoleOutputCP(void);
  extern 'UINT GetConsoleOutputCP(void);', :stdcall

  # BOOL CreateProcessW(LPCWSTR lpApplicationName, LPWSTR lpCommandLine, LPSECURITY_ATTRIBUTES lpProcessAttributes, LPSECURITY_ATTRIBUTES lpThreadAttributes, BOOL bInheritHandles, DWORD dwCreationFlags, LPVOID lpEnvironment, LPCWSTR lpCurrentDirectory, LPSTARTUPINFOW lpStartupInfo, LPPROCESS_INFORMATION lpProcessInformation);
  extern 'BOOL CreateProcessW(LPCWSTR lpApplicationName, LPWSTR lpCommandLine, LPSECURITY_ATTRIBUTES lpProcessAttributes, LPSECURITY_ATTRIBUTES lpThreadAttributes, BOOL bInheritHandles, DWORD dwCreationFlags, LPVOID lpEnvironment, LPCWSTR lpCurrentDirectory, LPSTARTUPINFOW lpStartupInfo, LPPROCESS_INFORMATION lpProcessInformation);', :stdcall

  # int MultiByteToWideChar(UINT CodePage, DWORD dwFlags, LPCSTR lpMultiByteStr, int cbMultiByte, LPWSTR lpWideCharStr, int cchWideChar);
  extern 'int MultiByteToWideChar(UINT, DWORD, LPCSTR, int, LPWSTR, int);', :stdcall
  # int WideCharToMultiByte(UINT CodePage, DWORD dwFlags, _In_NLS_string_(cchWideChar)LPCWCH lpWideCharStr, int cchWideChar, LPSTR lpMultiByteStr, int cbMultiByte, LPCCH lpDefaultChar, LPBOOL lpUsedDefaultChar);
  extern 'int WideCharToMultiByte(UINT, DWORD, LPCWCH, int, LPSTR, int, LPCCH, LPBOOL);', :stdcall

  # HANDLE CreateFileA(LPCSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
  extern 'HANDLE CreateFileA(LPCSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE);', :stdcall
  GENERIC_READ = 0x80000000
  GENERIC_WRITE = 0x40000000
  FILE_SHARE_READ = 0x00000001
  FILE_SHARE_WRITE = 0x00000002
  OPEN_EXISTING = 3
  INVALID_HANDLE_VALUE = 0xffffffff

  # HANDLE CreateNamedPipeA(LPCSTR lpName, DWORD dwOpenMode, DWORD dwPipeMode, DWORD nMaxInstances, DWORD nOutBufferSize, DWORD nInBufferSize, DWORD nDefaultTimeOut, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
  extern 'HANDLE CreateNamedPipeA(LPCSTR, DWORD, DWORD, DWORD, DWORD, DWORD, DWORD, LPSECURITY_ATTRIBUTES);', :stdcall
  # BOOL ConnectNamedPipe(HANDLE hNamedPipe, LPOVERLAPPED lpOverlapped);
  extern 'BOOL ConnectNamedPipe(HANDLE, LPVOID);', :stdcall
  # BOOL DisconnectNamedPipe(HANDLE hNamedPipe);
  extern 'BOOL DisconnectNamedPipe(HANDLE);', :stdcall
  # BOOL GetNamedPipeClientProcessId(HANDLE Pipe, PULONG ClientProcessId);
  extern 'BOOL GetNamedPipeClientProcessId(HANDLE, PULONG);', :stdcall
  PIPE_ACCESS_INBOUND = 0x00000001
  PIPE_ACCESS_OUTBOUND = 0x00000002
  PIPE_ACCESS_DUPLEX = 0x00000003

  # DWORD FormatMessageW(DWORD dwFlags, LPCVOID lpSource, DWORD dwMessageId, DWORD dwLanguageId, LPWSTR lpBuffer, DWORD nSize, va_list *Arguments);
  extern 'DWORD FormatMessageW(DWORD dwFlags, LPCVOID lpSource, DWORD dwMessageId, DWORD dwLanguageId, LPWSTR lpBuffer, DWORD nSize, va_list *Arguments);', :stdcall
  # HLOCAL LocalFree(HLOCAL hMem);
  extern 'HLOCAL LocalFree(HLOCAL hMem);', :stdcall
  FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100
  FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000

  # BOOL WINAPI SetConsoleCtrlHandler(PHANDLER_ROUTINE HandlerRoutine, BOOL Add);
  extern 'BOOL SetConsoleCtrlHandler(void *, BOOL Add);', :stdcall
  # BOOL WINAPI GenerateConsoleCtrlEvent(DWORD dwCtrlEvent, DWORD dwProcessGroupId);
  extern 'BOOL GenerateConsoleCtrlEvent(DWORD, DWORD);', :stdcall

  private def successful_or_if_not_messageout(r, method_name, exception: true)
    return true if not r.zero?
    err = Fiddle.win32_last_error
    if err == 0
      $stderr.puts "Info: #{method_name} returns zero but win32_last_error has successful zero."
      return true
    end
    string = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP, FREE)
    n = FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM,
      Fiddle::NULL,
      err,
      0x409, # en-US
      string,
      0,
      Fiddle::NULL
    )
    if n > 0
      str = wc2mb(string.ptr[0, n * 2])
      LocalFree(string)
    else
      msgerr = Fiddle.win32_last_error
      str = "error description unknow (FormatMessageW failed with #{msgerr})"
    end
    msg = "ERROR(#{method_name}): #{err}: #{str}"
    if exception
      raise msg
    else
      $stderr.puts msg
      return false
    end
  end

  def get_console_screen_buffer_info(handle)
    csbi = CONSOLE_SCREEN_BUFFER_INFO.malloc(FREE)
    r = GetConsoleScreenBufferInfo(handle, csbi)
    successful_or_if_not_messageout(r, 'GetConsoleScreenBufferInfo')
    return csbi
  end

  def set_console_screen_buffer_info_ex(handle, h, w, buffer_height)
    csbi = CONSOLE_SCREEN_BUFFER_INFOEX.malloc(FREE)
    csbi.cbSize = CONSOLE_SCREEN_BUFFER_INFOEX.size
    r = GetConsoleScreenBufferInfoEx(handle, csbi)
    successful_or_if_not_messageout(r, 'GetConsoleScreenBufferSize')
    csbi.dwSize_X = w
    csbi.dwSize_Y = buffer_height
    csbi.Left = 0
    csbi.Right = w - 1
    csbi.Top = [csbi.Top, buffer_height - h].min
    csbi.Bottom = csbi.Top + h - 1
    r = SetConsoleScreenBufferInfoEx(handle, csbi)
    return successful_or_if_not_messageout(r, 'SetConsoleScreenBufferInfoEx')
  end

  def set_console_window_info(handle, h, w)
    rect = SMALL_RECT.malloc(FREE)
    rect.Left = 0
    rect.Top = 0
    rect.Right = w - 1
    rect.Bottom = h - 1
    r = SetConsoleWindowInfo(handle, 1, rect)
    return successful_or_if_not_messageout(r, 'SetConsoleWindowInfo')
  end

  def set_console_window_size(handle, h, w)
    # expand buffer size to keep scrolled away lines
    buffer_h = h + 100

    r = set_console_screen_buffer_info_ex(handle, h, w, buffer_h)
    return false unless r

    r = set_console_window_info(handle, h, w)
    return false unless r

    return true
  end

  def create_console_file_handle(name)
    fh = CreateFileA(
      name,
      GENERIC_READ | GENERIC_WRITE,
      FILE_SHARE_READ | FILE_SHARE_WRITE,
      nil,
      OPEN_EXISTING,
      0,
      0
    )
    fh = [fh].pack("J").unpack1("J")
    successful_or_if_not_messageout(0, name) if fh == INVALID_HANDLE_VALUE
    fh
  end

  def close_handle(handle)
    r = CloseHandle(handle)
    return successful_or_if_not_messageout(r, "CloseHandle")
  end

  def free_console
    r = FreeConsole()
    return successful_or_if_not_messageout(r, "FreeConsole")
  end

  def attach_console(pid = ATTACH_PARENT_PROCESS, maybe_fail: false)
    r = AttachConsole(pid)
    return successful_or_if_not_messageout(r, 'AttachConsole') unless maybe_fail
    return r != 0 # || Fiddle.win32_last_error == 0 # this case couses problem
  end

  SHOWWINDOW_MAP = {
    conhost: {
      show: SW_SHOWNOACTIVE,
      hide: SW_HIDE,
    },
    "legacy-conhost": {
      show: SW_SHOWNOACTIVE,
      hide: SW_SHOWMINNOACTIVE,
    },
    "terminal": {
      show: SW_SHOWNOACTIVE,
      hide: SW_HIDE,
    }
  }

  def create_console(command, show = SW_SHOWNORMAL)
    converted_command = mb2wc("#{command}\0")
    console_process_info = PROCESS_INFORMATION.malloc(FREE)
    console_process_info.to_ptr[0, PROCESS_INFORMATION.size] = "\0".b * PROCESS_INFORMATION.size
    startup_info = STARTUPINFOW.malloc(FREE)
    startup_info.to_ptr[0, STARTUPINFOW.size] = "\0".b * STARTUPINFOW.size
    startup_info.cb = STARTUPINFOW.size
    startup_info.dwFlags = STARTF_USESHOWWINDOW
    startup_info.wShowWindow = show

    restore_console_control_handler do
      r = CreateProcessW(
        Fiddle::NULL, converted_command,
        Fiddle::NULL, Fiddle::NULL,
        0,
        CREATE_NEW_CONSOLE | CREATE_UNICODE_ENVIRONMENT,
        Fiddle::NULL, Fiddle::NULL,
        startup_info, console_process_info
      )
      successful_or_if_not_messageout(r, 'CreateProcessW')
    end
    close_handle(console_process_info.hProcess)
    close_handle(console_process_info.hThread)
    return console_process_info.dwProcessId
  end

  def get_std_handle(stdhandle)
    fh = GetStdHandle(stdhandle)
    successful_or_if_not_messageout(0, name) if fh == INVALID_HANDLE_VALUE
    fh
  end

  def mb2wc(str)
    size = MultiByteToWideChar(65001, 0, str, str.bytesize, '', 0)
    converted_str = "\x00".b * (size * 2)
    MultiByteToWideChar(65001, 0, str, str.bytesize, converted_str, size)
    converted_str
  end

  def wc2mb(str)
    size = WideCharToMultiByte(65001, 0, str, str.bytesize / 2, '', 0, 0, 0)
    converted_str = "\x00".b * size
    WideCharToMultiByte(65001, 0, str, str.bytesize / 2, converted_str, converted_str.bytesize, 0, 0)
    converted_str.force_encoding("UTF-8")
  end

  def read_console_output(handle, row, width)
    buffer = Fiddle::Pointer.malloc(Fiddle::SIZEOF_SHORT * width, FREE)
    n = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DWORD, FREE)
    r = ReadConsoleOutputCharacterW(handle, buffer, width, row << 16, n)
    successful_or_if_not_messageout(r, "ReadConsoleOutputCharacterW")
    return wc2mb(buffer[0, n.to_str.unpack1("L") * 2]).gsub(/ *$/, "")
  end

  def set_input_record(r, code)
    r.EventType = KEY_EVENT
    # r.bKeyDown = 1
    r.wRepeatCount = 1
    r.dwControlKeyState = code < 0 ? LEFT_ALT_PRESSED : 0
    code = code.abs
    r.wVirtualKeyCode = VkKeyScanW(code)
    r.wVirtualScanCode = MapVirtualKeyW(code, 0)
    r.UnicodeChar = code
    return r
  end

  def build_key_input_record(str)
    codes = str.chars.map do |c|
      c = "\r" if c == "\n"
      byte = c.getbyte(0)
      if c.bytesize == 1 and byte.allbits?(0x80) # with Meta key
        [-(byte ^ 0x80)]
      else
        mb2wc(c).unpack("S*")
      end
    end.flatten
    record = INPUT_RECORD_WITH_KEY_EVENT.malloc(FREE)
    records = codes.reduce("".b) do |records, code|
      set_input_record(record, code)
      record.bKeyDown = 1
      records << record.to_ptr.to_str
      record.bKeyDown = 0
      records << record.to_ptr.to_str
    end
    [records, codes.size * 2]
  end

  def write_console_input(handle, records, n)
    written = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DWORD, FREE)
    r = WriteConsoleInputW(handle, records, n, written)
    successful_or_if_not_messageout(r, 'WriteConsoleInput')
    return written.to_str.unpack1('L')
  end

  def get_number_of_console_input_events(handle)
    n = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DWORD, FREE)
    r = GetNumberOfConsoleInputEvents(handle, n)
    successful_or_if_not_messageout(r, 'GetNumberOfConsoleInputEvents')
    return n.to_str.unpack1('L')
  end

  def get_console_mode(handle)
    mode = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DWORD, FREE)
    mode[0, Fiddle::SIZEOF_DWORD] = "\0".b * Fiddle::SIZEOF_DWORD
    r = GetConsoleMode(handle, mode)
    successful_or_if_not_messageout(r, 'GetConsoleMode', exception: false) ? mode.to_str.unpack1('L') : nil
  end

  def set_console_mode(handle, mode)
    0 != SetConsoleMode(handle, mode)
  end

  def set_console_codepage(cp)
    r = SetConsoleCP(cp)
    return successful_or_if_not_messageout(r, 'SetConsoleCP', exception: false)
  end

  def set_console_output_codepage(cp)
    r = SetConsoleOutputCP(cp)
    return successful_or_if_not_messageout(r, 'SetConsoleOutputCP', exception: false)
  end

  def get_console_codepage()
    GetConsoleCP()
  end

  def get_console_output_codepage()
    GetConsoleOutputCP()
  end

  def generate_console_ctrl_event(event, pgrp)
    r = GenerateConsoleCtrlEvent(event, pgrp)
    return successful_or_if_not_messageout(r, 'GenerateConsoleCtrlEvent')
  end

  def create_named_pipe(name)
    ph = CreateNamedPipeA(%Q[\\\\.\\\pipe\\#{name}], PIPE_ACCESS_OUTBOUND, 0, 1, 0, 0, 0, nil)
    ph = [ph].pack("J").unpack1("L")
    successful_or_if_not_messageout(0, name) if ph == INVALID_HANDLE_VALUE
    ph
  end

  def connect_named_pipe(pipe_handle)
    r = ConnectNamedPipe(pipe_handle, nil)
    return successful_or_if_not_messageout(r, 'ConnectNamedPipe')
  end

  def disconnect_named_pipe(pipe_handle)
    r = DisconnectNamedPipe(pipe_handle)
    return successful_or_if_not_messageout(r, 'DisconnectNamedPipe')
  end

  def get_named_pipe_client_processid(pipe_handle, maybe_fail: false)
    pid = Fiddle::Pointer.malloc(Fiddle::SIZEOF_ULONG, FREE)
    r = GetNamedPipeClientProcessId(pipe_handle, pid)
    if !maybe_fail
      successful_or_if_not_messageout(r, "GetNamedPipeClientProcessId")
      return pid.to_str.unpack1("L")
    else
      return pid.to_str.unpack1("L") if r != 0
      return nil
    end
  end

  # Ctrl+C trap support
  # FreeConsole(), AttachConsole() clears console control handlers.
  # Make matter worse, C runtime does not provide the function to restore that handlers.
  # Yamatanooroti will ignore Ctrl+C and monitors the end of decoy process.

  def self.ignore_console_control_handler
    SetConsoleCtrlHandler(0, 1)
  end

  def self.restore_console_control_handler(&block)
    SetConsoleCtrlHandler(0, 0)
    if block_given?
      yield
      SetConsoleCtrlHandler(0, 1)
    end
  end

  @pipe = IO.pipe 
  @interrupt_catcher_pid = spawn("choice /m #InterruptCatcher", {:in => @pipe[0], [:out, :err] => "NUL"})
  @interrupt_catcher = Process.detach(@interrupt_catcher_pid)
  ignore_console_control_handler
  @interrupted_p = nil
  @pipe[0].close

  def self.interrupted?
    @interrupted_p ||
    unless @interrupt_catcher.alive?
      @interrupted_p = (@interrupt_catcher.value.exitstatus == 0)
    end
  end

  def self.at_exit
    @pipe[1].close unless @pipe[1].closed?
    if @interrupt_catcher.alive?
      sleep 0.01
      begin
        Process.kill("KILL", @interrupt_catcher_pid)
      rescue Errno::ESRCH # No such process
      end
    end
  end

  if Object.const_defined?(:Test) && Test.const_defined?(:Unit)
    Test::Unit.at_exit do
      Yamatanooroti::WindowsDefinition.at_exit
    end
  end

  extend self
end

if __FILE__ == $0
  at_exit { Yamatanooroti::WindowsDefinition.at_exit }
  DL = Yamatanooroti::WindowsDefinition
  def invoke_key(conin, str)
    DL.write_console_input(conin, *DL.build_key_input_record(str))
  end
  cin = DL.get_std_handle(DL::STD_INPUT_HANDLE)
  cout = DL.get_std_handle(DL::STD_OUTPUT_HANDLE)
  cerr = DL.get_std_handle(DL::STD_ERROR_HANDLE)

  binding.irb
  [cin, cout, cerr]
end
