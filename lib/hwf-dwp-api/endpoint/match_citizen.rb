# frozen_string_literal: true

module HwfDwpApi
  module Endpoint
    module MatchCitizen
      def match_citizen(citizen_params, header_info)
        @response = http_request(
          :post,
          '/capi/v2/citizens/match',
          headers: request_headers(header_info),
          body: match_request_body(citizen_params).to_json
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
        attributes[:firstName] = citizen_params[:first_name] unless blank?(citizen_params[:first_name])
        attributes[:ninoFragment] = citizen_params[:nino_fragment] unless blank?(citizen_params[:nino_fragment])
        attributes[:postcode] = citizen_params[:postcode] unless blank?(citizen_params[:postcode])

        {
          data: {
            type: 'Match',
            attributes: attributes
          }
        }
      end

      def blank?(value)
        value.nil? || value.to_s.strip.empty?
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
        error_type = {
          400 => :bad_request,
          401 => :invalid_token,
          403 => :forbidden,
          404 => :not_found,
          405 => :method_not_allowed,
          412 => :precondition_failed,
          422 => :unprocessable,
          429 => :rate_limited,
          503 => :service_unavailable
        }.fetch(@response.code, :standard_error)

        [response_hash.to_json, error_type]
      end

      def error_detail
        response_hash.dig('errors', 0, 'detail') || response_hash.dig('errors', 0, 'title')
      end
    end
  end
end
