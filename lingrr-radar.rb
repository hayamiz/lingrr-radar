#!/usr/bin/env ruby

require 'lingrr'

Net::HTTP.version_1_2

def notify_send(summary, msg)
  fork {
    exec("/usr/bin/notify-send", summary, msg)
  }
end

def main(argv)
  lingr = Lingr::Lingr.new(readuser(), readpasswd())
  while true
    lingr.rooms().each do |room|
      lingr.subscribe(room)
    end
    
    lingr.on("message") do |message|
      notify_send(message["message"]["nickname"],
                  message["message"]["text"])
    end

    while true
      res = lingr.observe()
      p res
    end
  end
end

if __FILE__ == $0
  main(ARGV.dup)
end
