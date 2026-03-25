# frozen_string_literal: true

require 'json'
require 'hwf_dwp_api/endpoint/token'
require 'hwf_dwp_api/endpoint/match_citizen'

module HwfDwpApi
  module Endpoint
    class << self
      require 'httparty'
      include Token
      include MatchCitizen

      attr_writer :client_cert, :client_key, :ca_bundle

      private

      def request_headers(header_info)
        {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'Authorization' => "Bearer #{header_info[:access_token]}",
          'correlation-id' => header_info[:correlation_id],
          'context' => header_info[:context],
          'policy-id' => header_info[:policy_id],
          'instigating-user-id' => 'hwf-api'
        }
      end

      def response_hash
        JSON.parse(@response.to_s)
      end

      def parse_standard_error_response
        message = "API: #{@response.code} - #{response_hash.dig('errors', 0,
                                                                'detail') || response_hash.dig('errors', 0, 'title')}"

        raise HwfDwpApiTokenError.new(message, :invalid_token) if @response.code == 401

        raise HwfDwpApiError.new(message, :invalid_request)
      end

      def api_url
        ENV.fetch('DWP_API_URL', nil)
      end

      def mtls_options
        options = {}
        options[:pem] = File.read(@client_cert) + File.read(@client_key) if @client_cert && @client_key
        options[:ssl_ca_file] = @ca_bundle if @ca_bundle
        options
      end
    end
  end
end
