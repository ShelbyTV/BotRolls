#!/usr/bin/env ruby
require "time"
require "redis"
require "open-uri"
require "httparty"
require "json"

# root working dir
dir_root = ARGV[1] == "dev" ? '' : "/home/gt/utils/BotRolls/"
load dir_root+'shelby_api.rb'

# Redis used for getting all youtube feed info and persisting last know video after polling
redis = Redis.new

service_config = redis.hgetall 'youtube:'+ARGV[0]
(puts "invalid youtube account"; exit) unless service_config

youtube_user = service_config["youtube_user"]
shelby_token = service_config["shelby_auth_token"]
shelby_roll_id = service_config["shelby_roll_id"]

# Redis used for persisting last know video
redis_key = "last_#{youtube_user}_video_time"

# This is the feed with the feeds latest videos (json)
feed_url = "http://gdata.youtube.com/feeds/api/users/" + youtube_user + "/uploads?v=2&alt=json"

begin
  # getting pub_date of last known video in feed
  pub_date_string = redis.get redis_key

  feed = JSON.parse(open(feed_url).read)
  entries = feed["feed"]["entry"]
  entries.reverse.each do |v|
    last_known_video_time = (pub_date_string =="" or pub_date_string.nil?) ? "" : Time.parse(pub_date_string)

    video = Hash.new
    video[:title] = v['title']['$t'] if v['title']
    video[:description] = v['media$group']['media$description']['$t'] if v['media$group'] and v['media$group']['media$description']
    video[:url] = v['link'][0]['href'] if v['link']
    video[:pub_date] = Time.parse(v['media$group']['yt$uploaded']['$t']) if v['media$group'] and v['media$group']['yt$uploaded']

    #move on if we have seen this pub_date before
    next if (last_known_video_time.is_a?(Time) and (video[:pub_date] <= last_known_video_time))

    if video[:url] and shelby_roll_id and shelby_token
      r = Shelby::API.create_frame(shelby_roll_id, shelby_token, video[:url], video[:description])
      puts "added: #{video[:pub_date]}"
    end

  end

  # setting pub_date of latest video
  if entries.first['media$group'] and entries.first['media$group']['yt$uploaded']
    redis.set(redis_key, entries.first['media$group']['yt$uploaded']['$t'])
  end
rescue => e
  puts "[ YT FEED ERROR ] #{youtube_user} : #{e}"
end
