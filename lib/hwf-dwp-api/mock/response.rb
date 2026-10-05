# frozen_string_literal: true

require 'json'
require 'securerandom'

module HwfDwpApi
  module Mock
    # The two things the endpoints read from an HTTP response: the status code and the body
    Response = Struct.new(:code, :body) do
      def self.json(code, payload)
        new(code, payload.to_json)
      end

      def self.data(data, links = nil)
        payload = { jsonapi: { version: '1.0' }, data: data }
        payload[:links] = links if links
        json(200, payload)
      end

      def self.not_found(detail)
        errors(404, [{ title: 'No Resource Found', detail: detail }])
      end

      def self.errors(code, errors)
        json(code, errors: errors.map { |error| { id: SecureRandom.uuid, status: code.to_s }.merge(error) })
      end

      def to_s
        body
      end
    end
  end
end
