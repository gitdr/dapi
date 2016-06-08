require 'open4'
require 'docker-api'
require 'grok-pure'
require 'pp'

class UpdateError < StandardError; end
class MissingArgument < StandardError; end

def add(zone, hostname, ip, key, server = nil)
  raise UpdateError, "can't find SOA for #{zone}" if server.nil?
  
  seq  = <<-";"
            server #{server}
            key #{zone}. #{key}
            zone #{zone}.
            update add #{hostname}.#{zone}. 86400 A #{ip}
            ;
    
  seq += "                send\n"

  invoke_nsupdate(seq)
end

def delete(zone, hostname, key, server = nil)
  raise UpdateError, "can't find SOA for #{zone}" if server.nil?
  
  seq  = <<-";"
            server #{server}
            key #{zone}. #{key}
            zone #{zone}.
            update delete #{hostname}.#{zone}. A
            ;
    
  seq += "                send\n"

  invoke_nsupdate(seq)
end

def invoke_nsupdate(seq = nil)
  raise MissingArgument, "missing update sequence" if seq.nil?

  Open4.popen4("nsupdate") do |pid, stdin, stdout, stderr|
    stdin << seq
    stdin.close_write
    err = stderr.read
    raise UpdateError, err unless err.empty?
  end
end

grok = Grok.new
grok.add_patterns_from_file("patterns/base")
pattern = "%{TIMESTAMP_ISO8601:ts}\s%{NOTSPACE:class}\s%{NOTSPACE:action}\s%{NOTSPACE:id}"
grok.compile(pattern)

Docker.url = 'unix:///var/run/docker.sock'

Open4::popen4 "docker events" do |pid, stdin, stdout, stderr|
  loop do
    IO.select([stdout])
    data = stdout.readline.strip
    match = grok.match(data)
    if match
      data = %w(ts class action id).map{|k| [k.to_sym,match.captures[k].first] }
      data = Hash[data]
    end

    if data[:class].eql?("container")

      case data[:action]
        when 'start'
          #pp Docker::Container.get(data[:id])
          ip = Docker::Container.get(data[:id]).info["NetworkSettings"]["IPAddress"]
          hostname = Docker::Container.get(data[:id]).info["Config"]["Hostname"]
          pp ip
          pp hostname

          add('test.local',
              hostname, 
              ip,
              'h3KXM9Oq9q5iXCfXrnlVNGRj7iUxJPB1b6G91PFZZ8WgYwaB8E0BkpnVDavFU30emC3RVVqiyLeel76NiqeBMg==',
              '172.17.0.1')

        when 'die'
          #ip = Docker::Container.get(data[:id]).info["NetworkSettings"]["IPAddress"]
          hostname = Docker::Container.get(data[:id]).info["Config"]["Hostname"]
          # pp ip
          pp hostname
          delete('test.local',
              hostname, 
              'h3KXM9Oq9q5iXCfXrnlVNGRj7iUxJPB1b6G91PFZZ8WgYwaB8E0BkpnVDavFU30emC3RVVqiyLeel76NiqeBMg==',
              '172.17.0.1')
          # DDNSUpdate.update('test.local', '', 'h3KXM9Oq9q5iXCfXrnlVNGRj7iUxJPB1b6G91PFZZ8WgYwaB8E0BkpnVDavFU30emC3RVVqiyLeel76NiqeBMg==', false, '172.17.0.1')
      end
    end

  
  end
end