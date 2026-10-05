# frozen_string_literal: true

require_relative 'hwf-dwp-api/connection'
require_relative 'hwf-dwp-api/connection_attribute_validation'
require_relative 'hwf-dwp-api/mock'

module HwfDwpApi
  ENV_MAPPING = {
    client_id: 'DWP_CLIENT_ID',
    client_secret: 'DWP_CLIENT_SECRET',
    client_cert: 'DWP_CLIENT_CERT',
    client_key: 'DWP_CLIENT_KEY',
    context: 'DWP_CONTEXT',
    policy_id: 'DWP_POLICY_ID',
    ca_bundle: 'DWP_CA_BUNDLE'
  }.freeze
  MOCK_CONNECTION = 'mock_dwp'

  extend ConnectionAttributeValidation

  # Mandatory attributes (loaded from ENV if not provided):
  # :client_id     - String (OAuth2 client ID)          - ENV: DWP_CLIENT_ID
  # :client_secret - String (OAuth2 client secret)      - ENV: DWP_CLIENT_SECRET
  # :client_cert   - String (PEM text or path to file)   - ENV: DWP_CLIENT_CERT
  # :client_key    - String (PEM text or path to file)   - ENV: DWP_CLIENT_KEY
  # :context       - String (source system identifier)  - ENV: DWP_CONTEXT
  # :policy_id     - String (matching policy ID)        - ENV: DWP_POLICY_ID
  #
  # Optional attributes:
  # :ca_bundle     - String (PEM text or path to file)   - ENV: DWP_CA_BUNDLE
  # :access_token  - String (cached access token)
  # :expires_in    - Time or String (token expiration, mandatory if access_token provided)
  #
  # DWP_API_CONNECTION=mock_dwp answers from test citizens instead of calling
  # DWP, and needs none of the attributes above. Any other value, or none,
  # uses the real connection.
  def self.new(connection_attributes = {})
    attributes = attributes_from_env.merge(connection_attributes)
    mock_connection? ? warn_mock_connection : validate_mandatory_attributes(attributes)
    HwfDwpApi::Connection.new(attributes)
  end

  def self.mock_connection?
    ENV.fetch('DWP_API_CONNECTION', nil) == MOCK_CONNECTION
  end

  def self.warn_mock_connection
    $stdout.puts "[HwfDwpApi] DWP_API_CONNECTION=#{MOCK_CONNECTION}: answering from test citizens, DWP is not called"
  end

  def self.attributes_from_env
    ENV_MAPPING.each_with_object({}) do |(key, env_var), hash|
      value = ENV.fetch(env_var, nil)
      hash[key] = value if value && !value.empty?
    end
  end

  private_class_method :attributes_from_env, :warn_mock_connection
end
