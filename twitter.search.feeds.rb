#!/usr/bin/env ruby

###########################################
# Dependencies
require "redis"
require "httparty"
require "grackle"
require "open-uri"
require "yaml"
require "json"

dir_root = "/home/gt/utils/BotRolls/"

load dir_root+'embedly_regexes.rb'
load dir_root+'shelby_api.rb'
#load 'embedly_regexes.rb'
#load 'shelby_api.rb'

###########################################
# Loading the config file w urls/search terms/twitter acct info
config = YAML.load( File.read("#{dir_root}feeds.yml") )
#config = YAML.load( File.read("feeds.yml") )

search_client = Grackle::Client.new

service_config = config["defaults"][ARGV[0]]
(puts "invalid service"; exit) unless service_config

search_term = URI.escape(service_config["search_term"] + " filter:links")
shelby_token = service_config["shelby_auth_token"]
shelby_roll_id = service_config["roll_id"]

###########################################
# Redis used for persisting last know video
redis = Redis.new
redis_key = "last_#{search_term}_tweet_id"
###########################################
###########################################

# getting id of last known tweet
last_old_video_id = redis.get redis_key
rpp = ARGV[1].to_i || 20

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
  #   limit on page is just trying to limit # vids passed through for now
  while search_result.results.length > 0 and page < 10
    search_result.results.each do |r|
      r.entities.urls.each do |u|
        if Embedly::Regexes.video_regexes_matches?(r.entities.urls.first.expanded_url)
          begin
            # Send vids to shelbz via shelby api
            # some tweets have multiple urls
            msg = "HT @#{r.from_user}: #{r.text}"
            r = Shelby::API.create_frame(shelby_roll_id, shelby_token, u.expanded_url, msg)
            puts "[ #{r['status']} ] #{msg}"
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
