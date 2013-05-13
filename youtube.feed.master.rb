#!/usr/bin/env ruby

#################################################
# Master process that spawns youtube feed parsers for every #
# account listed in the youtube.feeds.yml config file.              #
#                                                                                              #
# USAGE: ruby youtube.feed.master.rb  <yml file name>        #
#                                                                                              #
#################################################

require 'redis'
require 'timeout'
require 'net/smtp'

# redis used to pull yotube feeds from memory
redis = Redis.new
# directory and file to run
file_to_run = ARGV[1] == "dev" ? '' : '/home/gt/utils/BotRolls/'
file_to_run += 'youtube.feed.rb'

youtube_feeds = redis.keys 'youtube:*'

youtube_feeds.each do |feed|
    process = ['ruby', file_to_run, feed_info[:youtube_name],  ARGV[1].to_s].join(' ')
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
