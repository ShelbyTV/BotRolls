#!/usr/bin/env ruby
require "redis"
require "nokogiri"
require "grackle"
require "open-uri"
require "yaml"

config = YAML.load( File.read("feeds.yml") )

# what type of feed is this process pulling in, e.g. "espn", "tedx"
service = ARGV[0]

service_config = config["defaults"][service]
(puts "invalid service"; exit) unless service_config

feed_url = service_config["feed_url"]
token = service_config["token"]
secret = service_config["secret"]

# Grackle used for tweeting found videos for ingestion into shelby
# [this is shelby's key/secret pair]
(puts "must include twitter credentials"; exit) unless (token and secret)
consumer_key = config["defaults"]["consumer_app"]["consumer_key"]
consumer_secret = config["defaults"]["consumer_app"]["consumer_secret"]
tw_client = Grackle::Client.new(:auth=>{
  :type =>:oauth,
  :consumer_key => consumer_key, :consumer_secret => consumer_secret,
  :token => token,
  :token_secret => secret
})

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
    feed.xpath('//channel/item').each do |i|
      break if i.xpath('pubDate').inner_text == last_old_video_time
      vid = { "title" => i.xpath('title').inner_text,
              "link" => i.xpath('link').inner_text,
              "pubDate" => i.xpath('pubDate').inner_text }

      # Send vids to shelbz, for now via tweet (<140 char. duh)
      tweet = "#{vid['title'][0..90]}... #{vid['link']}"
      twitter_client.statuses.update! :status=> tweet
      puts tweet
      sleep 1
    end
    redis.set redis_key, first_new_video_time
  end
rescue => e
  puts "[#{Time.now}] [#{service.swap_case} VIDEO FEED ERROR]: #{e}"
end