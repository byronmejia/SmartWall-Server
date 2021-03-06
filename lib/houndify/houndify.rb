require 'openssl'
require 'securerandom'
require 'net/http'
require 'json'
require 'base64'

module Houndify
  attr_reader :secrets
  def self.set_secrets(id, key)
    @secrets = {
        id: id,
        key: Base64.urlsafe_decode64(key)
    }
  end
  def self.url; 'https://api.houndify.com/v1/text'; end
  def self.secrets; @secrets; end

  class Client
    attr_reader   :userID
    attr_reader   :options
    attr_accessor :requestID
    attr_reader   :time_stamp

    def initialize(userID, options = {})
      @userID = userID
      @options = options
      @requestID = options[:requestID] || SecureRandom.uuid
    end

    def request(query, options = {})
      @time_stamp = Time.now.to_i.to_s
      @requestID = SecureRandom.uuid
      uri = URI.parse(Houndify.url)
      headers = generate_headers(Latitude: -27.4519, Longitude: 153.0178)
      params = { :query => query }
      uri.query = URI.encode_www_form(params)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      code = http.head(uri.path, headers).code.to_i
      JSON.parse(http.get(uri, headers).body)
    end

    def generate_headers(options = {})
      raise 'No Client ID saved' if Houndify.secrets[:id].nil?
      raise 'No Client Key saved' if Houndify.secrets[:key].nil?
      request_data = @userID + ';' + @requestID
      encoded_data = sign_key(Houndify.secrets[:key], request_data + @time_stamp)

      request_info = {
          ClientID: Houndify.secrets[:id],
          UserID: @userID,
          RequestID: @requestID
      }.merge(options)

      {
          'Content-Type' => 'application/json',
          'Hound-Request-Authentication' => request_data,
          'Hound-Client-Authentication' => Houndify.secrets[:id] + ';' + @time_stamp + ';' + encoded_data,
          'Hound-Request-Info' => request_info.to_json
      }
    end
    private :generate_headers

    def sign_key(client_key, message)
      h = OpenSSL::HMAC.new(client_key, OpenSSL::Digest.new('sha256'))
      h.update(message)
      Base64.urlsafe_encode64(h.digest())
    end
    private :sign_key
  end
end
