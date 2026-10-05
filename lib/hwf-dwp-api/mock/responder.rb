# frozen_string_literal: true

module HwfDwpApi
  module Mock
    # Stands in for the DWP API: takes the path and options of an HTTP call
    # and returns the response a test citizen would get.
    module Responder
      TOKEN_PATH = '/citizen-information/oauth2/token'
      MATCH_PATH = '/capi/v2/citizens/match'
      CLAIMS_PATH = %r{\A/capi/v2/citizens/(?<guid>[^/]+)/claims\z}
      CITIZEN_PATH = %r{\A/capi/v2/citizens/(?<guid>[^/]+)\z}
      TOKEN_LIFETIME_SECONDS = 3600

      module_function

      def call(path, options = {})
        case path
        when TOKEN_PATH then token
        when MATCH_PATH then Match.response(match_attributes(options[:body]))
        when CLAIMS_PATH then Claims.response(Regexp.last_match[:guid], options[:query] || {})
        when CITIZEN_PATH then citizen(Regexp.last_match[:guid])
        else Response.not_found("The mock connection has no answer for #{path}")
        end
      end

      def token
        Response.json(200, access_token: 'mock-dwp-token', token_type: 'Bearer', expires_in: TOKEN_LIFETIME_SECONDS)
      end

      def match_attributes(body)
        JSON.parse(body.to_s).dig('data', 'attributes') || {}
      end

      def citizen(guid)
        citizen = TestCitizens.find_by_guid(guid)
        return Response.not_found('No citizen found for the supplied GUID') if citizen.nil?

        attributes = { 'guid' => guid }.merge(citizen['details'] || {})
        Response.data({ id: guid, type: 'Citizen', attributes: attributes }, self: "/capi/v2/citizens/#{guid}")
      end
    end
  end
end
