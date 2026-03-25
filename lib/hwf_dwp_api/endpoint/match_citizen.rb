# frozen_string_literal: true

module HwfDwpApi
  module Endpoint
    module MatchCitizen
      def match_citizen(citizen_params, header_info)
        @response = HTTParty.post(
          "#{api_url}/capi/v2/citizens/match",
          headers: request_headers(header_info),
          body: match_request_body(citizen_params).to_json,
          **mtls_options
        )

        process_match_response
      rescue OpenSSL::SSL::SSLError => e
        raise HwfDwpApiError.new("mTLS connection failed: #{e.message}", :certificate_error)
      rescue Errno::ECONNREFUSED => e
        raise HwfDwpApiError.new("Connection refused: #{e.message}", :connection_error)
      end

      private

      def match_request_body(citizen_params)
        attributes = {
          lastName: citizen_params[:last_name],
          dateOfBirth: citizen_params[:date_of_birth]
        }
        attributes[:firstName] = citizen_params[:first_name] if citizen_params[:first_name]
        attributes[:ninoFragment] = citizen_params[:nino_fragment] if citizen_params[:nino_fragment]
        attributes[:postcode] = citizen_params[:postcode] if citizen_params[:postcode]

        {
          data: {
            type: 'Match',
            attributes: attributes
          }
        }
      end

      def process_match_response
        return response_hash if @response.code == 200

        raise_match_error
      end

      def raise_match_error
        message, error_type = match_error_details
        raise HwfDwpApiTokenError.new(message, error_type) if @response.code == 401

        raise HwfDwpApiError.new(message, error_type)
      end

      def match_error_details
        {
          404 => ["Citizen not found: #{error_detail}", :not_found],
          422 => ["Unable to match citizen: #{error_detail}", :unprocessable],
          400 => ["Bad request: #{error_detail}", :bad_request],
          401 => ["Authentication failed: #{error_detail}", :invalid_token]
        }.fetch(@response.code, ["Unexpected response: #{@response.code} - #{error_detail}", :standard_error])
      end

      def error_detail
        response_hash.dig('errors', 0, 'detail') || response_hash.dig('errors', 0, 'title')
      end
    end
  end
end
