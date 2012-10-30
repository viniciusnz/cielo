module Cielo
  class Connection
    attr_reader :environment
    def initialize
      @environment = eval(Cielo.environment.to_s.capitalize)      
    end
    
    def request!(params={})
      Curl.post(self.environment::API_URL, params)
    end
  end
end