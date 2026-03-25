# frozen_string_literal: true

module HwfDwpApi
  module Endpoint
    module Token
      def token(client_id, client_secret)
        @response = HTTParty.post(
          "#{api_url}/oauth2/token",
          headers: { "Content-Type" => "application/x-www-form-urlencoded" },
          body: {
            client_id: client_id,
            client_secret: client_secret,
            grant_type: "client_credentials"
          },
          **mtls_options
        )

        process_token_response
      rescue OpenSSL::SSL::SSLError => e
        raise HwfDwpApiError.new("mTLS connection failed: #{e.message}", :certificate_error)
      rescue Errno::ECONNREFUSED => e
        raise HwfDwpApiError.new("Connection refused: #{e.message}", :connection_error)
      end

      private

      def process_token_response
        return response_hash if @response.code == 200

        error_code = response_hash["error"]
        error_desc = response_hash["error_description"]
        message = "OAuth token request failed: #{error_code} - #{error_desc}"

        error_type = case @response.code
                     when 401 then :invalid_client
                     when 400 then :"#{error_code}"
                     else :token_error
                     end

        raise HwfDwpApiError.new(message, error_type)
      rescue HwfDwpApiError
        raise
      rescue StandardError => e
        raise HwfDwpApiError.new(e.message, :standard_error)
      end
    end
  end
end
