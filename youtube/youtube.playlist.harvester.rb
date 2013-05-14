#!/usr/bin/env ruby

#######################################
#
# This script is to be used to harvest videos from a YouTube Playlist
#  into a Shelby Roll
#
#  required arguments:
#   - playlist_id
#   - shelby_roll_id
#   - shelby_auth_token
#
#######################################
require "json"
require "open-uri"
require "httparty"

#dir_root = "/home/gt/utils/BotRolls/"
dir_root = "" # in development env
load dir_root+'shelby_api.rb'

playlist_id = ARGV[0]
shelby_roll_id = ARGV[1]
shelby_auth_token = ARGV[2]

(puts "requires playlist_id, shelby_roll_id, shelby_auth_token as input"; exit) unless (playlist_id and shelby_roll_id and shelby_auth_token)

feed_url = "http://gdata.youtube.com/feeds/api/playlists/" + playlist_id
max_results = 10

begin
  # This is the rss feed with the feeds latest videos
  if response = JSON.parse(open(feed_url+'?alt=json&max-results=1').read) and response['feed']
    @videos = []
    total_entries = response['feed']['openSearch$totalResults']['$t']

    # get all videos from playlist
    (total_entries/max_results + 1).times do |i|
      start_index = i*max_results + 1

      playlist_url = feed_url+'?alt=json&start-index='+start_index.to_s+'&max-results='+max_results.to_s
      puts "getting: #{start_index} - #{start_index+max_results + 1}"
      if r = JSON.parse(open(playlist_url).read) and r['feed'] and r['feed']['entry']
        r['feed']['entry'].each do |v|
          url = v['link'][0]["href"]
          description = v['yt$description']["$t"] if v['yt$description']
          @videos << {:url => url, :description => description}
        end
      else
        puts "error while looping through playlist"
      end

    end

    @videos.reverse.each do |v|
      print '.' if Shelby::API.create_frame(shelby_roll_id, shelby_auth_token, v[:url], v[:description])
    end
    puts "done."
  else
    puts "[#{Time.now}] [VIDEO FEED ERROR]: bad response from youtube : #{response}"
  end
rescue => e
  puts "[#{Time.now}] [VIDEO FEED ERROR]: #{e}"
end
