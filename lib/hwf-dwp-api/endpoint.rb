# frozen_string_literal: true

require 'json'
require 'hwf-dwp-api/endpoint/token'
require 'hwf-dwp-api/endpoint/match_citizen'
require 'hwf-dwp-api/endpoint/citizen'
require 'hwf-dwp-api/endpoint/claims'

module HwfDwpApi
  module Endpoint
    class << self
      require 'httparty'
      include Token
      include MatchCitizen
      include Citizen
      include Claims

      attr_writer :client_cert, :client_key, :ca_bundle

      # Any way of failing to reach DWP: the consumer counts these as a DWP failure
      NETWORK_ERRORS = [
        Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH, Errno::ETIMEDOUT,
        Errno::EPIPE, SocketError, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, EOFError
      ].freeze

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

      # Every call to DWP goes through here, so the mock connection can answer instead
      def http_request(method, path, options = {})
        return HwfDwpApi::Mock::Responder.call(path, options) if HwfDwpApi.mock_connection?

        HTTParty.public_send(method, "#{api_url}#{path}", **options, **mtls_options)
      rescue *NETWORK_ERRORS => e
        raise HwfDwpApiError.new("Connection failed: #{e.class}: #{e.message}", :connection_error)
      end

      def response_hash
        JSON.parse(@response.to_s)
      rescue JSON::ParserError
        raise_unexpected_body
      end

      # A body that is not JSON usually comes from a gateway in front of DWP (502, 504, maintenance page)
      def raise_unexpected_body
        status = @response.code.to_i
        body = { 'errors' => [{ 'status' => status.to_s, 'title' => 'Unexpected response',
                                'detail' => "Response from DWP was not JSON (HTTP #{status})" }] }
        raise HwfDwpApiError.new(body.to_json, status >= 500 ? :service_unavailable : :standard_error)
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

      def debug_output
        ENV['DWP_DEBUG'] ? $stdout : nil
      end

      def mtls_options
        options = {}
        options[:pem] = "#{resolve_pem(@client_cert)}\n#{resolve_pem(@client_key)}" if @client_cert && @client_key
        options[:cert_store] = build_cert_store if @ca_bundle
        options[:debug_output] = debug_output if debug_output
        options
      end

      def build_cert_store
        ca_pem = resolve_pem(@ca_bundle)
        store = OpenSSL::X509::Store.new
        ca_pem.scan(/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m).each do |cert|
          store.add_cert(OpenSSL::X509::Certificate.new(cert))
        end
        store
      end

      def resolve_pem(value)
        value&.include?('BEGIN') ? value : File.read(value)
      end
    end
  end
end
