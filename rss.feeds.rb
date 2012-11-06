#!/usr/bin/env ruby
require "redis"
require "nokogiri"
require "grackle"
require "open-uri"
require "yaml"
require "httparty"
require "json"

dir_root = "/home/gt/utils/BotRolls/"
load dir_root+'shelby_api.rb'

config = YAML.load( File.read("/home/gt/utils/BotRolls/feeds.yml") )

# what type of feed is this process pulling in, e.g. "espn", "tedx"
service = ARGV[0]

service_config = config["defaults"][service]
(puts "invalid service"; exit) unless service_config

feed_url = service_config["feed_url"]
shelby_token = service_config["shelby_auth_token"]
shelby_roll_id = service_config["roll_id"]

# Redis used for persisting last know video
redis = Redis.new
redis_key = "last_#{service}_video_time"

# This is the rss feed with the feeds latest videos
feed = Nokogiri::XML(open(feed_url))

begin
  # getting pubDate of last known video in feed
  key = redis.get redis_key
  last_old_video_time = (key == "" or key == nil) ? "" : Time.parse(key)
  
  feed.xpath('//channel/item').reverse.each do |i|
    next if (last_old_video_time.is_a?(Time) and Time.parse(i.xpath('pubDate').inner_text) <= last_old_video_time)
    
    vid = { "title" => i.xpath('title').inner_text,
            "link" => i.xpath('link').inner_text,
            "pubDate" => i.xpath('pubDate').inner_text }

    # Send vids to shelbz
    description = "#{vid['title'][0..90]}... #{i.xpath('link').inner_text}"
    if shelby_roll_id and shelby_token
      r = Shelby::API.create_frame(shelby_roll_id, shelby_token, vid['link'], description)
    end
    puts description
    sleep 1
  end
  redis.set redis_key, i.xpath('pubDate').inner_text
rescue => e
  puts "[#{Time.now}] [#{service.swapcase} VIDEO FEED ERROR]: #{e}"
end