#!/usr/bin/env ruby

###########################################
# Dependencies
require "redis"
require "httparty"
require "grackle"
require "open-uri"
require "yaml"
require "json"

#load '/home/nos/MacawFeed/embedly_regexes.rb'
#load '/home/nos/MacawFeed/shelby_api.rb'
load 'embedly_regexes.rb'
load 'shelby_api.rb'

###########################################
# Loading the config file w urls/search terms/twitter acct info 
#config = YAML.load( File.read("/home/nos/MacawFeed/feeds.yml") )
config = YAML.load( File.read("feeds.yml") )


###########################################
# the twitter seach term that only returns results with links:

search_term = URI.escape(ARGV[0] + " filter:links")
rpp = ARGV[1].to_i || 20

search_client = Grackle::Client.new

service_config = config["defaults"][ARGV[0]]
(puts "invalid service"; exit) unless service_config

search_term = service_config["search_term"]
shelby_token = service_config["shelby_auth_token"]
shelby_roll_id = service_config["roll_id"]

token = service_config["tw_token"]
secret = service_config["tw_secret"]

###########################################
# Grackle used for tweeting found videos for ingestion into shelby
# [this is shelby's key/secret pair]
# NOTE: eventually this should be done via the Shelby API
(puts "must include twitter credentials"; exit) unless (token and secret)
=begin
consumer_key = config["defaults"]["consumer_app"]["consumer_key"]
consumer_secret = config["defaults"]["consumer_app"]["consumer_secret"]
tw_client = Grackle::Client.new(:auth=>{
  :type =>:oauth,
  :consumer_key => consumer_key, :consumer_secret => consumer_secret,
  :token => token,
  :token_secret => secret
})
=end

###########################################
# Redis used for persisting last know video
redis = Redis.new
redis_key = "last_#{search_term}_tweet_id"
###########################################
###########################################

# getting id of last known tweet
last_old_video_id = redis.get redis_key

# do twitter search:
page = 1
search_result = search_client[:search].search? :q => search_term, 
                    :include_entities => true, 
                    :rpp => rpp, 
                    :since_id => last_old_video_id,
                    :page => page

# storing the max_id in redis
redis.set redis_key, search_result.max_id

begin
  # this loops through all of the tweets since last sweep
  while search_result.results.length > 0 and page < 5 # lit on page is just trying to limit time it takes to run this
    puts "page #{page}:"
    search_result.results.each do |r|
      r.entities.urls.each do |u|
        if Embedly::Regexes.video_regexes_matches?(r.entities.urls.first.expanded_url)      
          # Send vids to shelbz via shelby api
          begin
            # some tweets have multiple urls
            r = Shelby::API.create_frame(shelby_roll_id, shelby_token, u.expanded_url, r.text)
            puts r.parsed_response
          rescue => e
            puts "[#{Time.now}] [#{search_term.swapcase} GRACKLE ERROR]: #{e}"
          end
          sleep 0.5
        end
      end
    end
    
    page += 1
        
    search_result = search_client[:search].search? :q => search_term, 
                        :include_entities => true, 
                        :rpp => rpp, 
                        :since_id => last_old_video_id,
                        :page => page
  end
  
rescue => e
  puts "[#{Time.now}] [#{search_term.swapcase} ERROR]: #{e}"
end
