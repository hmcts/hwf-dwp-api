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

    # Retrieves citizen details by GUID.
    # Uses the stored citizen_guid from match_citizen if no guid is provided.
    #
    # Returns JSON hash with citizen data
    def get_citizen(guid = @citizen_guid, correlation_id = SecureRandom.uuid)
      raise HwfDwpApiError.new('No citizen GUID available. Call match_citizen first.', :validation) unless guid

      response = HwfDwpApi::Endpoint.citizen(
        guid,
        header_info(correlation_id)
      )
      @citizen_guid = response.dig('data', 'id')
      response
    end

    # Retrieves claims for a citizen by GUID.
    # Uses the stored citizen_guid from match_citizen/get_citizen if no guid is provided.
    #
    # Optional filters:
    #   :benefit_type   - String or Array of benefit type(s)
    #   :effective_from - String YYYY-MM-DD
    #   :effective_to   - String YYYY-MM-DD
    #
    # Returns JSON hash with claims data
    def get_claims(guid = @citizen_guid, filters = {}, correlation_id = SecureRandom.uuid)
      raise HwfDwpApiError.new('No citizen GUID available. Call match_citizen first.', :validation) unless guid

      response = HwfDwpApi::Endpoint.claims(
        guid,
        header_info(correlation_id),
        filters
      )
      update_citizen_guid(response)
      response
    end

    private

    def update_citizen_guid(response)
      new_guid = response.dig('data', 0, 'attributes', 'guid')
      @citizen_guid = new_guid if new_guid
    end
  end
end
