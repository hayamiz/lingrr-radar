#!/usr/bin/env ruby

require 'net/http'
require 'rubygems'
require 'json'

Net::HTTP.version_1_2

def notify_send(msg)
  fork {
    exec("/usr/bin/notify-send", msg)
  }
end

class Lingr
  def self.post(path, parameters = {}, observe = nil)
    port = self.port(observe)
    
    begin
      Net::HTTP.start("lingr.com", port) do |http|
        req = Net::HTTP::Post.new(self.make_path("/api" + path, parameters))
        req["Content-type"] = "application/x-www-form-urlencoded"
        req["Content-Length"] = "0"
        $stderr.puts "GetRequest:"+"lingr.com:"+port.to_s+"/"+self.make_path("/api" + path, parameters)
        res = http.request(req)
        $stderr.puts res.body
        JSON.parse(res.body)
      end
    rescue StandardError => err
      $stderr.puts err
      $stderr.puts err.backtrace
      nil
    end
  end

  def self.get(path, parameters = {}, observe = nil)
    port = self.port(observe)
    
    begin
      Net::HTTP.start("lingr.com", port) do |http|
        req = Net::HTTP::Get.new(self.make_path("/api" + path, parameters))
        req["Content-type"] = "application/x-www-form-urlencoded"
        $stderr.puts "GetRequest:"+"lingr.com:"+port.to_s+"/"+req.to_s
        res = http.request(req)
        $stderr.puts res.body
        JSON.parse(res.body)
      end
    rescue StandardError => err
      $stderr.puts err
      $stderr.puts err.backtrace
      nil
    end
  end

  def self.make_path(path, parameters = {})
    query = parameters.map{|k,v|
      URI.escape(k.to_s) + "=" + URI.escape(v.to_s)
    }.join("&")
    
    if query.empty?
      path
    else
      path + "?" + query
    end
  end

  def self.port(observe = nil)
    if observe
      8080
    else
      80
    end
  end

  def initialize(username, password)
    @username = username
    @password = password

    self.connect()

    self.mainloop()
  end

  def connect()
    @session = Session.create(@username, @password)
  end

  def mainloop()
    while true
      @session.rooms().each do |room|
        @session.subscribe(room)
      end
    
      while true
        res = @session.observe()
        res["events"].each do |event|
          p event
          notify_send(event["message"]["nickname"] + ": " + event["message"]["text"])
        end
      end
    end
  end

  class Session
    attr_reader :username
    attr_reader :password
    attr_reader :session

    def initialize(session, username, password)
      @session = session
      @username = username
      @password = password
    end
    
    def self.create(username, password)
      res = Lingr.post("/session/create", 
                       {"user" => username, "password" => password})
      if res && res["status"] == "ok"
        Session.new(res["session"], username, password)
      else
        nil
      end
    end

    def post(path, params = {})
      params["session"] = @session
      res = Lingr.post(path, params)
      if res && res["status"] == "ok"
        res
      else
        nil
      end
    end

    def get(path, params = {})
      params["session"] = @session
      observe = (path == "/event/observe")
      res = Lingr.get(path, params, observe)
      if res && res["status"] == "ok"
        res
      else
        nil
      end
    end

    def rooms()
      self.post("/user/get_rooms")["rooms"]
    end
    
    def subscribe(room)
      @counter = self.post("/room/subscribe", {"room" => room})["counter"]
    end
    
    def observe()
      if @counter
        res = self.get("/event/observe", {"counter" => @counter})
        @counter = res["counter"]
      else
        raise Exception.new("No counter")
      end
      res
    end
  end
end


def readuser()
  $stdout.print "Username: "
  $stdout.flush()
  readline.strip
end

def readpasswd()
  $stdout.print "Password: "
  $stdout.flush()
  system("stty -echo")
  pass = readline.strip
  system("stty echo")
  pass
end

if __FILE__ == $0
  Lingr.new(readuser(), readpasswd())
end
