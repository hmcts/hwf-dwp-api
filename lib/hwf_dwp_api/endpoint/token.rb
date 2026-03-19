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
      end

      private

      def process_token_response
        return response_hash if @response.code == 200

        message = "API: #{response_hash["error"]} - #{response_hash["error_description"]}"
        raise HwfDwpApiError.new(message, :token_error) if [401, 400, 500].include?(@response.code)
      rescue HwfDwpApiError
        raise
      rescue StandardError => e
        raise HwfDwpApiError.new(e.message, :standard_error)
      end
    end
  end
end
