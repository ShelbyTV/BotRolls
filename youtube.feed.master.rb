#!/usr/bin/env ruby

#
# HOW TO USE GOES HERE
#

require 'timeout'
require 'yaml'
require 'net/smtp'

#dir = '/home/gt/utils/BotRolls/'
dir = ''

config = YAML.load( File.read(dir+"youtube.feeds.yml") )

feeds = config["defaults"].keys

def send_email(opts={})
    opts[:server]      ||= 'localhost'
    opts[:to]       ||= 'henry@shelby.tv'
    opts[:from]        ||= 'botrolls@shelby.tv'
    opts[:from_alias]  ||= 'BotRolls'
    opts[:subject]     ||= "[Error: youtube.feed.master.rb]"
    opts[:body]        ||= "Important stuff!"

    msg = <<END_OF_MESSAGE
From: #{opts[:from_alias]} <#{opts[:from]}>
To: <#{opts[:to]}>
Subject: #{opts[:subject]}

#{opts[:body]}
END_OF_MESSAGE

    Net::SMTP.start(opts[:server]) do |smtp|
       smtp.send_message msg, opts[:from], opts[:to]
    end
end

feeds.each do |feed|
    pid = Process.spawn('ruby youtube.feed.rb '+feed)

    begin
        Timeout.timeout(120) do
            Process.wait pid
        end
    rescue Timeout::Error
        Process.kill 9, pid
        # collect status so it doesn't stick around as zombie process
        Process.wait pid
    end
    puts "#{feed} child exited, pid = #{pid}"
end
