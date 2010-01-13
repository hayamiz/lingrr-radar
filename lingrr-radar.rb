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
  lingr.on(Lingr::Event::MESSAGE) do |message|
    notify_send(message["message"]["nickname"],
                message["message"]["text"])
  end

  reconnect = false

  while true
    if reconnect
      lingr.connect()
      reconnect = false
    end

    begin
      lingr.rooms().each do |room|
        lingr.subscribe(room)
      end
      
      while true
        res = lingr.observe()
        p res
      end
    rescue SocketError => err
      $stderr.puts "SocketError : sleeps"
      $stderr.puts err.backtrace
      sleep(10)
      reconnect = true
    end
  end
end

if __FILE__ == $0
  main(ARGV.dup)
end
