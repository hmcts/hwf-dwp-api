# frozen_string_literal: true

require_relative "hwf_dwp_api/connection"
require_relative "hwf_dwp_api/connection_attribute_validation"

module HwfDwpApi
  class << self
    include ConnectionAttributeValidation

    # Mandatory attributes:
    # :client_id     - String (OAuth2 client ID)
    # :client_secret - String (OAuth2 client secret)
    # :client_cert   - String (path to PEM client certificate for mTLS)
    # :client_key    - String (path to PEM client private key for mTLS)
    # :context       - String (provisioned source system identifier)
    # :policy_id     - String (agreed matching policy ID)
    #
    # Optional attributes:
    # :ca_bundle     - String (path to CA bundle PEM for mTLS)
    # :access_token  - String (cached access token)
    # :expires_in    - Time or String (token expiration, mandatory if access_token provided)
    def new(connection_attributes)
      validate_mandatory_attributes(connection_attributes)
      HwfDwpApi::Connection.new(connection_attributes)
    end
  end
end
