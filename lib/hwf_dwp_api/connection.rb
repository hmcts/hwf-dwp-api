# frozen_string_literal: true

require_relative 'authentication'
require 'hwf_dwp_api/hwf_dwp_api_error'
require 'hwf_dwp_api/hwf_dwp_api_token_error'
require 'securerandom'

# Connection methods
# IMPORTANT: To be able to get benefit information you need to call match_citizen method first
# # # # # # # # # # # # # # # # # # # # # # # #
# Method name: match_citizen(citizen_params, correlation_id)
#
# Method attributes example:
# { last_name: "Smith",
#   date_of_birth: "1985-03-15",
#   nino_fragment: "4021" }   # optional - last 4 digits of NINO (excluding suffix)
#
# Returns GUID string on success
#
# # # # # # # # # # # # # # # # # # # # # # # #

module HwfDwpApi
  class Connection
    attr_reader :citizen_guid, :authentication

    def initialize(connection_attributes)
      @authentication = HwfDwpApi::Authentication.new(connection_attributes)
      @context = connection_attributes[:context]
      @policy_id = connection_attributes[:policy_id]
    end

    def header_info(correlation_id)
      {
        access_token: access_token,
        correlation_id: correlation_id,
        context: @context,
        policy_id: @policy_id
      }
    end

    def access_token
      @authentication.access_token
    end

    # citizen_params:
    #   :last_name      - String (required)
    #   :date_of_birth  - String YYYY-MM-DD (required)
    #   :first_name     - String (optional)
    #   :nino_fragment   - String last 4 digits (optional)
    #   :postcode       - String (optional)
    #
    # Returns GUID string on success
    def match_citizen(citizen_params, correlation_id = SecureRandom.uuid)
      response = HwfDwpApi::Endpoint.match_citizen(
        citizen_params,
        header_info(correlation_id)
      )
      @citizen_guid = response.dig('data', 'id')
      response
    end
  end
end
