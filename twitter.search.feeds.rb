#!/usr/bin/env ruby
require "redis"
require "grackle"
require "open-uri"
require "yaml"

#config = YAML.load( File.read("/home/gt/utils/VideoFeedRss/feeds.yml") )

# the twitter seach term:
search_term = URI.escape(ARGV[0])
rpp = ARGV[1].to_i || 20
search_client = Grackle::Client.new
=begin
service_config = config["defaults"][service]
(puts "invalid service"; exit) unless service_config

search_term = service_config["search_term"]
token = service_config["tw_token"]
secret = service_config["tw_secret"]

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
=end
# Redis used for persisting last know video
#redis = Redis.new
#redis_key = "last_#{search_term.join('_')}_video_time"

# getting pubDate of last known video in feed
#last_old_video_time = redis.get redis_key

# do twitter search:
search_result = search_client[:search].search? :q => search_term, :include_entities => true, :rpp => rpp

begin
  # TODO:
  #first_new_video_id = 
  #if last_old_video_id != first_new_video_id
    search_result.results.each do |r|
      #break if r.id == last_old_video_id
      puts r.text if r.entities.urls
      #vid = { "title" => r.title,
      #        "link" => r.link,
      #        "timestamp" => r.time } 
              # FIX ^

      # Send vids to shelbz, for now via tweet (<140 char. duh)
      #tweet = "#{vid['title'][0..90]}... #{vid['link']}"
      #tw_client.statuses.update! :status=> tweet
      #puts tweet
      #sleep 1
    end
    #redis.set redis_key, first_new_video_id
  #end
rescue => e
  puts "[#{Time.now}] [#{search_term.swapcase} VIDEO FEED ERROR]: #{e}"
end