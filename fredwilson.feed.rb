#!/usr/bin/env ruby
require "redis"
require "nokogiri"
require "open-uri"
require "yaml"
require "httparty"
require "json"

dir_root = "/home/gt/utils/BotRolls/"
#dir_root = ""
load dir_root+'shelby_api.rb'
load dir_root+'embedly_regexes.rb'

feed_url = "http://feeds.feedburner.com/avc"
shelby_token = 
shelby_roll_id = 

# Redis used for persisting last know post
redis = Redis.new
redis_key = "last_avc_video_time"

feed = Nokogiri::XML(open(feed_url))

begin
  # getting pubDate of last known post in feed
  key = redis.get redis_key
  last_old_video_time = (key == "" or key == nil) ? "" : Time.parse(key)
  
  feed.xpath('//item').reverse.each do |i|
    pubDate = i.xpath('pubDate').inner_text
    # dont look at this item if we have seen it before
    break if last_old_video_time.is_a?(Time) and (Time.parse(pubDate) <= last_old_video_time)

    post_title = i.xpath('title').inner_text
    post_link = i.xpath('link').inner_text
    post_content = i.content
    
    # scan the post for urls
    urls = post_content.scan(/(?i)\b((?:https?:\/\/|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’]))/)
    # flatten the results and remove any nil entries from scan
    urls.flatten! 
    urls.delete_if {|u| u == nil }
    
    description = "(from a entry on avc.com) #{post_title} :: #{post_link}"
    
    urls.each do |url|
      if Embedly::Regexes.video_regexes_matches?(url)
        #r = Shelby::API.create_frame(shelby_roll_id, shelby_token, url, description)
        puts description
      end

      redis.set redis_key, pubDate
    end
  end

end