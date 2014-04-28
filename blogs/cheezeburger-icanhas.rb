# encoding: UTF-8
#!/usr/bin/env ruby
require "redis"
require "open-uri"
require "httparty"
require "json"

dir_root = "/home/gt/utils/BotRolls/utils/"
#dir_root = "" #for local dev
load dir_root+'shelby_api.rb'
load dir_root+'embedly_regexes.rb'



feed_url = "http://ajax.googleapis.com/ajax/services/feed/load?v=1.0&num=10&q=http://icanhas.cheezburger.com/rss"
shelby_token = "uKEqRMN2uABdry7V68Cp"
shelby_roll_id = "535e915d59b0520992000007"

# Redis used for persisting last know post
redis = Redis.new
redis_key = "last_icanhas_video_time"

begin
  # getting pubDate of last known post in feed
  key = redis.get redis_key
  last_old_video_time = (key == "" or key == nil) ? "" : Time.parse(key)

  feed = JSON.parse(open(feed_url).read)
  entries = feed["responseData"]["feed"]["entries"]

  entries.reverse.each do |v|
    pubDate = v['publishedDate']

    # dont look at this item if we have seen it before
    next if last_old_video_time.is_a?(Time) and (Time.parse(pubDate) <= last_old_video_time)

    post_title = v['title']
    post_link = v['link']
    post_content = v['content']

    # scan the post for urls
    urls = post_content.scan(/(?i)\b((?:https?:\/\/|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’]))/)
    # flatten the results and remove any nil entries from scan
    urls.flatten!
    urls.uniq!
    urls.delete_if {|u| u == nil }

    description = "#{post_title}"

    urls.each do |url|
      if Embedly::Regexes.video_regexes_matches?(url)
        short_link = {:original => post_link}
        r = Shelby::API.create_frame(shelby_roll_id, shelby_token, url, description, short_link)
        puts description
      end
    end
    redis.set redis_key, pubDate
  end
rescue => e
  puts "[ DailyWhat FEED ERROR ] #{e}"
end
