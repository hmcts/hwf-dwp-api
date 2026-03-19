# frozen_string_literal: true

module HwfDwpApi
  module ConnectionAttributeValidation
    require_relative "hwf_dwp_api_error"

    def validate_mandatory_attributes(connection_attributes)
      client_id_present?(connection_attributes[:client_id])
      client_secret_present?(connection_attributes[:client_secret])
      validate_mtls_attributes(connection_attributes)
      context_present?(connection_attributes[:context])
      policy_id_present?(connection_attributes[:policy_id])
      expires_in_valid?(connection_attributes[:expires_in]) if connection_attributes[:access_token]
    end

    private

    def client_id_present?(value)
      return true unless value.nil? || value.empty?

      raise HwfDwpApiError.new("Connection attributes validation: CLIENT ID is missing", :validation)
    end

    def client_secret_present?(value)
      return true unless value.nil? || value.empty?

      raise HwfDwpApiError.new("Connection attributes validation: CLIENT SECRET is missing", :validation)
    end

    def validate_mtls_attributes(attributes)
      client_cert_present?(attributes[:client_cert])
      client_key_present?(attributes[:client_key])
    end

    def client_cert_present?(value)
      return true unless value.nil? || value.empty?

      raise HwfDwpApiError.new("Connection attributes validation: CLIENT CERT is missing", :validation)
    end

    def client_key_present?(value)
      return true unless value.nil? || value.empty?

      raise HwfDwpApiError.new("Connection attributes validation: CLIENT KEY is missing", :validation)
    end

    def context_present?(value)
      return true unless value.nil? || value.empty?

      raise HwfDwpApiError.new("Connection attributes validation: CONTEXT is missing", :validation)
    end

    def policy_id_present?(value)
      return true unless value.nil? || value.empty?

      raise HwfDwpApiError.new("Connection attributes validation: POLICY ID is missing", :validation)
    end

    def expires_in_valid?(value)
      expires_in_blank?(value)
      validate_date_format(value)
      true
    rescue ArgumentError
      false
    end

    def expires_in_blank?(value)
      return unless value.nil? || (value.is_a?(String) && value.empty?)

      raise HwfDwpApiError.new("Connection attributes validation: EXPIRES IN is missing", :validation)
    end

    def validate_date_format(value)
      case value
      when String
        string_date_validation(value)
      when Time, Integer, Float
        if Time.at(value) < Time.now
          raise HwfDwpApiError.new("Connection attributes validation: EXPIRES IN is in past", :validation)
        end
      end
    end

    def string_date_validation(value)
      if DateTime.parse(value).to_time < Time.now
        raise HwfDwpApiError.new("Connection attributes validation: EXPIRES IN is in past", :validation)
      end
    rescue Date::Error
      raise HwfDwpApiError.new("Connection attributes validation: EXPIRES IN has invalid format", :validation)
    end
  end
end
