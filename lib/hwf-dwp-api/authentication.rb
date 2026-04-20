# frozen_string_literal: true

require_relative 'endpoint'

module HwfDwpApi
  class Authentication
    attr_reader :access_token, :expires_in

    def initialize(connection_attributes)
      @client_id = connection_attributes[:client_id]
      @client_secret = connection_attributes[:client_secret]
      configure_mtls(connection_attributes)
      prepare_token(connection_attributes)
    end

    def token
      if @token.nil?
        log('[HwfDwpApi] No token present, requesting new token...')
        get_token
      elsif expired?
        log("[HwfDwpApi] Token expired (expired at #{@expires_in}), requesting new token...")
        get_token
      else
        log("[HwfDwpApi] Using existing token (expires at #{@expires_in})")
      end
      access_token
    end

    def get_token
      log("[HwfDwpApi] Requesting token for client_id=#{@client_id}")
      token_response = HwfDwpApi::Endpoint.token(@client_id, @client_secret)
      @token = token_response.transform_keys(&:to_sym)
      set_expired_time
      load_access_token
      log("[HwfDwpApi] Token received, expires at #{@expires_in}")
    end

    def expired?
      time_now = Time.now + 100
      @expires_in <= time_now
    end

    private

    def log(message)
      $stdout.puts message
    end

    def configure_mtls(attributes)
      cert = attributes[:client_cert] ? 'present' : 'nil'
      key = attributes[:client_key] ? 'present' : 'nil'
      ca = attributes[:ca_bundle] ? 'present' : 'nil'
      log("[HwfDwpApi] Configuring mTLS (cert=#{cert}, key=#{key}, ca=#{ca})")
      HwfDwpApi::Endpoint.client_cert = attributes[:client_cert]
      HwfDwpApi::Endpoint.client_key = attributes[:client_key]
      HwfDwpApi::Endpoint.ca_bundle = attributes[:ca_bundle]
    end

    def set_expired_time
      @expires_in = Time.now + @token[:expires_in]
    end

    def load_access_token
      @access_token = @token[:access_token]
    end

    def prepare_token(attributes)
      if attributes[:access_token]
        log("[HwfDwpApi] Using cached token (expires at #{attributes[:expires_in]})")
        @access_token = attributes[:access_token]
        @expires_in = preformat_expires_in(attributes[:expires_in])
        @token = {
          access_token: @access_token,
          expires_in: @expires_in
        }
      else
        token
      end
    end

    def preformat_expires_in(value)
      case value
      when String
        DateTime.parse(value).to_time
      when Time, Integer, Float
        Time.at(value)
      end
    end
  end
end
