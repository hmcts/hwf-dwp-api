# frozen_string_literal: true

require_relative "hwf_dwp_api/connection"
require_relative "hwf_dwp_api/connection_attribute_validation"

module HwfDwpApi
  ENV_MAPPING = {
    client_id: "DWP_CLIENT_ID",
    client_secret: "DWP_CLIENT_SECRET",
    client_cert: "DWP_CLIENT_CERT",
    client_key: "DWP_CLIENT_KEY",
    context: "DWP_CONTEXT",
    policy_id: "DWP_POLICY_ID",
    ca_bundle: "DWP_CA_BUNDLE"
  }.freeze

  class << self
    include ConnectionAttributeValidation

    # Mandatory attributes (loaded from ENV if not provided):
    # :client_id     - String (OAuth2 client ID)          - ENV: DWP_CLIENT_ID
    # :client_secret - String (OAuth2 client secret)      - ENV: DWP_CLIENT_SECRET
    # :client_cert   - String (path to PEM client cert)   - ENV: DWP_CLIENT_CERT
    # :client_key    - String (path to PEM client key)    - ENV: DWP_CLIENT_KEY
    # :context       - String (source system identifier)  - ENV: DWP_CONTEXT
    # :policy_id     - String (matching policy ID)        - ENV: DWP_POLICY_ID
    #
    # Optional attributes:
    # :ca_bundle     - String (path to CA bundle PEM)     - ENV: DWP_CA_BUNDLE
    # :access_token  - String (cached access token)
    # :expires_in    - Time or String (token expiration, mandatory if access_token provided)
    def new(connection_attributes = {})
      attributes = attributes_from_env.merge(connection_attributes)
      validate_mandatory_attributes(attributes)
      HwfDwpApi::Connection.new(attributes)
    end

    private

    def attributes_from_env
      ENV_MAPPING.each_with_object({}) do |(key, env_var), hash|
        value = ENV.fetch(env_var, nil)
        hash[key] = value if value && !value.empty?
      end
    end
  end
end
