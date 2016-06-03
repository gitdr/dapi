require 'open4'
require 'docker-api'
require 'grok-pure'
require 'pp'

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
          pp Docker::Container.get(data[:id])
          pp Docker::Container.get(data[:id]).info["NetworkSettings"]["IPAddress"]
          pp Docker::Container.get(data[:id]).info["Config"]["Hostname"]
        when 'die'
          pp Docker::Container.get(data[:id]).info["Config"]["Hostname"]
      end
    end

  
  end
end