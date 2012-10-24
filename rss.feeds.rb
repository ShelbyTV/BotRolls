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
token = service_config["tw_token"]
secret = service_config["tw_secret"]
shelby_token = service_config["shelby_auth_token"]
shelby_roll_id = service_config["roll_id"]


# Grackle used for tweeting found videos for ingestion into shelby
# [this is shelby's key/secret pair]
if (token and secret)
  consumer_key = config["defaults"]["consumer_app"]["consumer_key"]
  consumer_secret = config["defaults"]["consumer_app"]["consumer_secret"]
  tw_client = Grackle::Client.new(:auth=>{
    :type =>:oauth,
    :consumer_key => consumer_key, :consumer_secret => consumer_secret,
    :token => token,
    :token_secret => secret
  })
end

# Redis used for persisting last know video
redis = Redis.new
redis_key = "last_#{service}_video_time"

# getting pubDate of last known video in feed
last_old_video_time = redis.get redis_key

# This is the rss feed with the feeds latest videos
feed = Nokogiri::XML(open(feed_url))

begin
  first_new_video_time = feed.xpath('//channel/item').first.xpath('pubDate').inner_text
  if last_old_video_time != first_new_video_time
    feed.xpath('//channel/item').reverse.each do |i|
      break if last_old_video_time.is_a?(Date) and Date.parse(i.xpath('pubDate').inner_text) > last_old_video_time
      
      vid = { "title" => i.xpath('title').inner_text,
              "link" => i.xpath('link').inner_text,
              "pubDate" => i.xpath('pubDate').inner_text }

      # Send vids to shelbz
      tweet = "#{vid['title'][0..90]}"
      if token and secret
        tw_client.statuses.update! :status=> tweet
      elsif shelby_roll_id and shelby_token
        r = Shelby::API.create_frame(shelby_roll_id, shelby_token, vid['link'], tweet)
      end
      puts tweet
      sleep 1
    end
    redis.set redis_key, first_new_video_time
  end
rescue => e
  puts "[#{Time.now}] [#{service.swapcase} VIDEO FEED ERROR]: #{e}"
end