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
      get_token if @token.nil? || expired?
      access_token
    end

    def get_token
      token_response = HwfDwpApi::Endpoint.token(@client_id, @client_secret)
      @token = token_response.transform_keys(&:to_sym)
      set_expired_time
      load_access_token
    end

    def expired?
      time_now = Time.now + 100
      @expires_in <= time_now
    end

    private

    def configure_mtls(attributes)
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
