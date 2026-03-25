# frozen_string_literal: true

module HwfDwpApi
  module Endpoint
    module Citizen
      def citizen(guid, header_info)
        @response = HTTParty.get(
          "#{api_url}/capi/v2/citizens/#{guid}",
          headers: request_headers(header_info),
          **mtls_options
        )

        process_citizen_response
      rescue OpenSSL::SSL::SSLError => e
        raise HwfDwpApiError.new("mTLS connection failed: #{e.message}", :certificate_error)
      rescue Errno::ECONNREFUSED => e
        raise HwfDwpApiError.new("Connection refused: #{e.message}", :connection_error)
      end

      private

      def process_citizen_response
        return response_hash if @response.code == 200

        raise_citizen_error
      end

      def raise_citizen_error
        message = response_hash.to_json
        error_type = {
          404 => :not_found,
          401 => :invalid_token
        }.fetch(@response.code, :standard_error)

        raise HwfDwpApiTokenError.new(message, error_type) if @response.code == 401

        raise HwfDwpApiError.new(message, error_type)
      end
    end
  end
end
