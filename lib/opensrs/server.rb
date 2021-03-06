require "uri"
require "net/https"
require "digest/md5"
require "openssl"

module OpenSRS
  class BadResponse < StandardError; end
  
  class Server
    attr_accessor :server, :username, :password, :key, :logger

    def initialize(options = {})
      @server   = URI.parse(options[:server] || "https://rr-n1-tor.opensrs.net:55443/")
      @username = options[:username]
      @password = options[:password]
      @key      = options[:key]
      @logger   = options[:logger]
    end

    def call(options = {})
      attributes = {
        :protocol => "XCP"
      }
      
      xml = xml_processor.build(attributes.merge!(options))
      log(xml, "Request XML for #{options[:object]} #{options[:action]}")

      response        = http.post(server.path, xml, headers(xml))
      log(response.body, "Response XML for #{options[:object]} #{options[:action]}")
      parsed_response = xml_processor.parse(response.body)
      
      return OpenSRS::Response.new(parsed_response, xml, response.body)
    rescue Net::HTTPBadResponse
      raise OpenSRS::BadResponse, "Received a bad response from OpenSRS. Please check that your IP address is added to the whitelist, and try again."
    end

    def xml_processor
      @@xml_processor
    end

    def self.xml_processor=(name)
      require File.dirname(__FILE__) + "/xml_processor/#{name.to_s.downcase}"
      @@xml_processor = OpenSRS::XmlProcessor.const_get("#{name.to_s.capitalize}")
    end

    OpenSRS::Server.xml_processor = :nokogiri
    
    private
    
    def headers(request)
      headers = {
        "Content-Length"  => request.length.to_s,
        "Content-Type"    => "text/xml",
        "X-Username"      => username,
        "X-Signature"     => signature(request)
      }
      
      return headers
    end
    
    def signature(request)
      signature = Digest::MD5.hexdigest(request + key)
      signature = Digest::MD5.hexdigest(signature + key)
      signature
    end
    
    def http
      http = Net::HTTP.new(server.host, server.port)
      http.use_ssl = (server.scheme == "https")
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http
    end

    def log(data, message)
      return unless logger

      message = "[OpenSRS] " + message
      line = [message, data].join("\n")
      logger.info(line)
    end
  end
end
