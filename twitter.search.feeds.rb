#!/usr/bin/env ruby

###########################################
# Dependencies
require "redis"
require "grackle"
require "open-uri"
require "yaml"
require "json"

load 'embedly_regexes.rb'

###########################################
# Loading the config file w urls/search terms/twitter acct info 
#config = YAML.load( File.read("/home/gt/utils/VideoFeedRss/feeds.yml") )
config = YAML.load( File.read("feeds.yml") )


###########################################
# the twitter seach term:

search_term = URI.escape(ARGV[0] + " filter:links")
rpp = ARGV[1].to_i || 20

search_client = Grackle::Client.new

service_config = config["defaults"][ARGV[0]]
(puts "invalid service"; exit) unless service_config

search_term = service_config["search_term"]
token = service_config["tw_token"]
secret = service_config["tw_secret"]

###########################################
# Grackle used for tweeting found videos for ingestion into shelby
# [this is shelby's key/secret pair]
# NOTE: eventually this should be done via the Shelby API
(puts "must include twitter credentials"; exit) unless (token and secret)

consumer_key = config["defaults"]["consumer_app"]["consumer_key"]
consumer_secret = config["defaults"]["consumer_app"]["consumer_secret"]
tw_client = Grackle::Client.new(:auth=>{
  :type =>:oauth,
  :consumer_key => consumer_key, :consumer_secret => consumer_secret,
  :token => token,
  :token_secret => secret
})

###########################################
# Redis used for persisting last know video
redis = Redis.new
redis_key = "last_#{search_term}_video_id"
###########################################
###########################################

# getting pubDate of last known video in feed
last_old_video_id = redis.get redis_key

# do twitter search:
search_result = search_client[:search].search? :q => search_term, :include_entities => true, :rpp => rpp, :since_id => last_old_video_id

begin
  redis.set redis_key, search_result.max_id
  
  search_result.results.each do |r|
    if r.entities.urls.length > 0 and Embedly::Regexes.video_regexes_matches?(r.entities.urls.first.expanded_url)      

      # Send vids to shelbz, for now via tweet (<140 char. duh)
      # NOTE: eventually this should be done via the Shelby API
      begin
        tw_client.statuses.retweet!(:id => r.id) if r.entities.urls.length > 0
      rescue => e
        puts "[#{Time.now}] [#{search_term.swapcase} GRACKLE ERROR]: #{e}"
      end
      
      puts r.entities.urls.first.expanded_url
      
      sleep 0.5
    else
      #puts r.text
      print "."
    end
  end
rescue => e
  puts "[#{Time.now}] [#{search_term.swapcase} ERROR]: #{e}"
end