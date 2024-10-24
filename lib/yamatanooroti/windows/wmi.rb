require "win32ole"

class Yamatanooroti
  module WMI
    WIN32OLE.codepage = WIN32OLE::CP_UTF8
    @locator = WIN32OLE.new('WbemScripting.SWbemLocator')
    @server = @locator.ConnectServer('.', 'root\cimv2')
    @server.Security_.ImpersonationLevel = 3

    def self.server
      @server
    end

    module Win32_Process
      class << self
        def eq(k, v)
          "#{k} = '#{v}'"
        end

        def like(k, v)
          "#{k} LIKE \"#{v}\""
        end

        def &(k, v)
          "#{k} AND #{v}"
        end

        def query(filters, *properties)
          properties << "*" if properties.empty?
          filters = Array(filters)
          where = filters.empty? ? "" : " WHERE #{filters.join(" OR ")}"
          query = "SELECT #{properties&.join(",") || "*"} FROM Win32_Process#{where}"
          list = WMI.server.ExecQuery(query)
          list.each.map do |process|
            process.GetObjectText_.lines.reduce({}) do |hash, line|
              if kv = line.match(/(\w*) = (.*);/)
                key = kv[1]
                value = kv[2].match(/\A".*"\z/)
                if value == nil
                  value = kv[2]&.to_i
                else
                  value = value[0].undump
                end
                hash[key] = value
              end
              hash
            end
          end || []
        end

        def query_name(name, *properties)
          query(eq("Name", name), *properties)
        end

        def query_name_and_commandline(name, commandline, *properties)
          query(self.&(eq("Name", name), like("CommandLine", "%#{commandline}%")), *properties)
        end

        def query_pid(pid, *properties)
          query(eq("ProcessId"), pid, *properties)
        end

        def query_ppid(ppid, *properties)
          query(eq("ParentProcessId"), ppid, *properties)
        end
      end
    end
  end
end

# ary = WMI::Win32_Process.query_ppid(Process.pid, "Name", "CommandLine", "ProcessId", "ParentProcessId", "CreationDate", "UserModeTime", "KernelModeTime")
# ary.each { |e| puts [e["Name"], e["ProcessId"]] }

if $0 == __FILE__
  WMI = Yamatanooroti::WMI
  binding.irb
end
