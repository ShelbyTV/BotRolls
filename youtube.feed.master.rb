#!/usr/bin/env ruby

#################################################
# Master process that spawns youtube feed parsers for every #
# account listed in the youtube.feeds.yml config file.              #
#                                                                                              #
# USAGE: ruby youtube.feed.master.rb  <yml file name>        #
#                                                                                              #
#################################################

require 'timeout'
require 'yaml'
require 'net/smtp'

# name of yml config file
filename = ARGV[0]
dir = ARGV[1] == "dev" ? '' : '/home/gt/utils/BotRolls/'

config = YAML.load( File.read(dir+filename) )

feeds = config["defaults"].keys

feeds.each do |feed|
    process = ['ruby',dir,'youtube.feed.rb', feed, filename, ARGV[1].to_s].join(' ')
    pid = Process.spawn(process)
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
