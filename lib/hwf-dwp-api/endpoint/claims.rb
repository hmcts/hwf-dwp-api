# frozen_string_literal: true

module HwfDwpApi
  module Endpoint
    module Claims
      def claims(guid, header_info, filters = {})
        @response = HTTParty.get(
          "#{api_url}/capi/v2/citizens/#{guid}/claims",
          headers: request_headers(header_info),
          query: claims_query_params(filters),
          **mtls_options
        )

        process_claims_response
      rescue OpenSSL::SSL::SSLError => e
        raise HwfDwpApiError.new("mTLS connection failed: #{e.message}", :certificate_error)
      rescue Errno::ECONNREFUSED => e
        raise HwfDwpApiError.new("Connection refused: #{e.message}", :connection_error)
      end

      private

      def claims_query_params(filters)
        params = {}
        params[:benefitType] = filters[:benefit_type] if filters[:benefit_type]
        params[:effectiveFromDate] = filters[:effective_from] if filters[:effective_from]
        params[:effectiveToDate] = filters[:effective_to] if filters[:effective_to]
        params
      end

      def process_claims_response
        return response_hash if @response.code == 200

        raise_claims_error
      end

      def raise_claims_error
        message = response_hash.to_json
        error_type = {
          400 => :bad_request,
          404 => :not_found,
          401 => :invalid_token
        }.fetch(@response.code, :standard_error)

        raise HwfDwpApiTokenError.new(message, error_type) if @response.code == 401

        raise HwfDwpApiError.new(message, error_type)
      end
    end
  end
end
