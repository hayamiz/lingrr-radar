#!/usr/bin/env ruby

require 'net/http'
require 'rubygems'
require 'json'


module Lingr
  module Event
    MESSAGE = :message
    PRESENCE = :presence
  end

  class Lingr
    def initialize(username, password)
      @username = username
      @password = password
      
      @handlers = Hash.new

      self.connect()
    end
    
    def connect()
      @session = Session.new(@username, @password)
      @session.create()
    end
    
    def rooms()
      @session.post("/user/get_rooms")["rooms"]
    end
    
    def subscribe(room)
      @counter = @session.post("/room/subscribe", {:room => room})["counter"]
    end
    
    def observe()
      if @counter
        res = @session.get("/event/observe",
                          {:counter => @counter})
        if res
        @counter = res["counter"] if res["counter"]
          if res["events"]
            res["events"].each do |event|
              handlers = if event["message"]
                           @handlers[Event::MESSAGE]
                         elsif event["presence"]
                           @handlers[Event::PRESENCE]
                         end
              puts "handlers: "
              
              handlers.each do |handler|
                handler.call(event)
              end if handlers
            end
          end
        end
      else 
        raise Exception.new("No counter")
      end
      res
    end

    def on(event_name, &handler)
      handlers = @handlers[event_name]
      unless handlers
        handlers = Array.new
        @handlers[event_name] = handlers
      end
      handlers << handler
    end
  end

  class Session
    attr_reader :username
    attr_reader :password
    attr_reader :session
    
    def initialize(username, password)
      @username = username
      @password = password
    end
    
    def self.request(req)
      port = if req.path =~ /\A\/api\/event\/observe/
               8080
             else
               80
             end
      $stderr.puts "lingr.com:#{port}#{req.path}"
      begin
        Net::HTTP.start("lingr.com", port) do |http|
          req["Content-type"] = "application/x-www-form-urlencoded"
          req["Content-Length"] = "0" if req.method == "POST"
          res = http.request(req)
          $stderr.puts res.body
          JSON.parse(res.body)
        end
      rescue Timeout::Error => err
        $stderr.puts err
        $stderr.puts err.backtrace
        nil
      rescue Exception => err
        raise err
      end
    end
    
    def self.post(path, params = {})
      req = Net::HTTP::Post.new(self.make_path("/api" + path, params))
      res = self.request(req)
      if res && res["status"] == "ok"
        res
      else
        nil
      end
    end

    def self.get(path, params = {})
      req = Net::HTTP::Get.new(self.make_path("/api" + path, params))
      res = self.request(req)
      if res && res["status"] == "ok"
        res
      else
        nil
      end
    end
    
    def post(path, params = {})
      unless params[:session] || params["session"]
        params[:session] = @session
      end
      p params
      self.class.post(path, params)
    end

    def get(path, params = {})
      unless params[:session] || params["session"]
        params[:session] = @session
      end
      p params
      self.class.get(path, params)
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

    def create()
      res = Session.post("/session/create",
                         {"user" => @username, "password" => @password})
      if res && res["status"] == "ok"
        @session = res["session"]
        p @session
      else
        nil
      end
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
