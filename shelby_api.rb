module Shelby
  class API
    include HTTParty
    base_uri 'api.gt.shelby.tv/v1'
  
    def self.get_user_info(nickname)
      u = get("/user/#{nickname}").parsed_response
      r = (u['status'] == 200) ? u['result'] : nil
    end
    
    def self.get_roll(id)
      r = get( "/roll/#{id}" ).parsed_response
    end
    
    def self.create_frame(roll_id, token, url, text, source=nil)
      u = post("/roll/#{roll_id}/frames", :query => { :auth_token => token, 
                  :url => url, 
                  :text => text, 
                  :source => source })
    end
  
  end
end