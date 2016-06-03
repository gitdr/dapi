require "grok-pure"
require 'pp'

grok = Grok.new
grok.add_patterns_from_file("patterns/base")
pattern = "%{TIMESTAMP_ISO8601:ts} %{GREEDYDATA:id}:\s\\(from\s%{GREEDYDATA:image}\\)\s%{GREEDYDATA:action}"
grok.compile(pattern)

data = "2016-06-03T16:23:44.000000000+01:00 7f7a2ec475045699ab9623fe744adbbfc12433fefbe6f35ce77a71ea70bd2471: (from sameersbn/bind:latest) destroy"

match = grok.match(data)
pp match
pp match.captures
pp %w(ts id image action).map{|k| {k => match.captures[k].first}}