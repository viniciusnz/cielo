#encoding: utf-8
module Cielo
  class Transaction
    def initialize
      @connection = Cielo::Connection.new
    end
    def create!(parameters={})
      analysis_parameters(parameters)
      message = xml_builder("requisicao-transacao") do |xml|
        if parameters[:numero_cartao]
          xml.tag!("dados-portador") do
            xml.tag!(:numero, parameters[:numero_cartao].to_s)
            
            xml.tag!(:validade, parameters[:validade].to_s)
            [:indicador, :"codigo-seguranca"].each do |key|
              xml.tag!(key.to_s, parameters[key].to_s)
            end
          end
        end
        xml.tag!("dados-pedido") do
          [:numero, :valor, :moeda, :"data-hora", :descricao, :idioma, :"soft-descriptor"].each do |key|
            xml.tag!(key.to_s, parameters[key].to_s)
          end
        end
        xml.tag!("forma-pagamento") do
          [:bandeira, :produto, :parcelas].each do |key|
            xml.tag!(key.to_s, parameters[key].to_s)
          end
        end
        xml.tag!("url-retorno", parameters[:"url-retorno"]) if parameters[:"url-retorno"]
        xml.autorizar parameters[:autorizar].to_s
        xml.capturar parameters[:capturar].to_s
        xml.tag!("campo-livre", parameters[:"campo-livre"]) if parameters[:"campo-livre"]
        xml.tag!("bin", parameters[:bin]) if parameters[:bin]
      end
      make_request! message
    end
    
    def verify!(cielo_tid)
      return nil unless cielo_tid
      message = xml_builder("requisicao-consulta", :before) do |xml|
        xml.tid "#{cielo_tid}"
      end
      
      make_request! message
    end
    
    def catch!(cielo_tid)
      return nil unless cielo_tid
      message = xml_builder("requisicao-captura", :before) do |xml|
        xml.tid "#{cielo_tid}"
      end
      make_request! message
    end
    
    private
    def analysis_parameters(parameters={})
      [:numero, :valor, :bandeira].each do |parameter|
        raise Cielo::MissingArgumentError, "Required parameter #{parameter} not found" unless parameters[parameter]
      end
      parameters.merge!(:validade => ["%04d" % parameters[:validade_ano], "%02d" % parameters[:validade_mes]].join("")) if parameters[:validade_ano]
      parameters.merge!(:indicador => "1") unless parameters[:indicador]
      parameters.merge!(:moeda => "986") unless parameters[:moeda]
      parameters.merge!(:"data-hora" => Time.now.strftime("%Y-%m-%dT%H:%M:%S")) unless parameters[:"data-hora"]
      parameters.merge!(:descricao => "") unless parameters[:indicador]
      parameters.merge!(:idioma => "PT") unless parameters[:idioma]
      parameters.merge!(:"soft-descriptor" => "") unless parameters[:indicador]
      parameters.merge!(:produto => "1") unless parameters[:produto]
      parameters.merge!(:parcelas => "1") unless parameters[:parcelas]
      parameters.merge!(:autorizar => "2") unless parameters[:autorizar]
      parameters.merge!(:capturar => "true") unless parameters[:capturar]
      parameters.merge!(:"url-retorno" => Cielo.return_path) unless parameters[:"url-retorno"]
      parameters.merge!(:"campo-livre" => "") unless parameters[:"campo-livre"]
      parameters.merge!(:"bin" => parameters[:numero_cartao][0..5]) if parameters[:numero_cartao]
      parameters
    end
    
    def xml_builder(group_name, target=:after, &block)
      xml = Builder::XmlMarkup.new
      xml.instruct! :xml, :version=>"1.0", :encoding=>"ISO-8859-1"
      xml.tag!(group_name, :id => "#{Time.now.to_i}", :versao => "1.2.0") do
        block.call(xml) if target == :before
        xml.tag!("dados-ec") do
          xml.numero Cielo.numero_afiliacao
          xml.chave Cielo.chave_acesso
        end
        block.call(xml) if target == :after
      end
      xml
    end
    
    def make_request!(message)
      params = { :mensagem => message }
      
      result = @connection.request! params
      parse_response(result)
    end
    
    def parse_response(response)
      case response
      when Net::HTTPSuccess
        document = REXML::Document.new(response.body_str)
        parse_elements(document.elements)
      else
        {:erro => { :codigo => "000", :mensagem => "Impossível contactar o servidor"}}
      end
    end
    def parse_elements(elements)
      map={}
      elements.each do |element|
        element_map = {}
        element_map = element.text if element.elements.empty? && element.attributes.empty?
        element_map.merge!("value" => element.text) if element.elements.empty? && !element.attributes.empty?
        element_map.merge!(parse_elements(element.elements)) unless element.elements.empty?
        map.merge!(element.name => element_map)
      end
      map.symbolize_keys
    end
  end
end