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
            type: "Match",
            attributes: attributes
          }
        }
      end

      def process_match_response
        case @response.code
        when 200
          response_hash
        when 404
          raise HwfDwpApiError.new(
            "Citizen not found: #{error_detail}", :not_found
          )
        when 422
          raise HwfDwpApiError.new(
            "Unable to match citizen: #{error_detail}", :unprocessable
          )
        when 400
          raise HwfDwpApiError.new(
            "Bad request: #{error_detail}", :bad_request
          )
        when 401
          raise HwfDwpApiTokenError.new(
            "Authentication failed: #{error_detail}", :invalid_token
          )
        else
          raise HwfDwpApiError.new(
            "Unexpected response: #{@response.code} - #{error_detail}", :standard_error
          )
        end
      end

      def error_detail
        response_hash.dig("errors", 0, "detail") || response_hash.dig("errors", 0, "title")
      end
    end
  end
end
