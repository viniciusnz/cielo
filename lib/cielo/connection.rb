module Cielo
  class Connection
    attr_reader :environment
    def initialize
      @environment = eval(Cielo.environment.to_s.capitalize)      
    end
    
    def request!(params={})
      str_params = ""
      params.each do |key, value| 
        str_params+="&" unless str_params.empty?
        str_params+="#{key}=#{value}"
      end
      Curl.post(self.environment::API_URL, str_params)
    end
  end
end