# frozen_string_literal: true

module HwfDwpApi
  module Mock
    # Finds the test citizen a match request points at
    module Match
      REQUIRED_ATTRIBUTES = %w[lastName dateOfBirth].freeze
      # Compared only when both the request and the test citizen have them
      OPTIONAL_ATTRIBUTES = %w[firstName ninoFragment postcode].freeze

      module_function

      # attributes: the "attributes" hash of the match request body
      def response(attributes)
        candidates = TestCitizens.all.select { |citizen| matches?(citizen['match_attributes'], attributes) }

        case candidates.size
        when 0 then Response.not_found('Unable to find a unique match for the supplied matching dataset')
        when 1 then matched(candidates.first)
        else further_details_required(attributes)
        end
      end

      def matches?(expected, given)
        REQUIRED_ATTRIBUTES.all? { |name| same?(expected[name], given[name]) } &&
          OPTIONAL_ATTRIBUTES.all? { |name| optional_match?(expected[name], given[name]) }
      end

      def optional_match?(expected, given)
        blank?(expected) || blank?(given) || same?(expected, given)
      end

      def matched(citizen)
        Response.data(
          id: TestCitizens.guid_for(citizen),
          type: 'MatchResult',
          attributes: { matchingScenario: citizen['matching_scenario'] || 'scenario_1' }
        )
      end

      # More than one test citizen fits: ask for the details that were not sent
      def further_details_required(attributes)
        missing = OPTIONAL_ATTRIBUTES.select { |name| blank?(attributes[name]) }
        return Response.errors(422, [{ title: 'Unprocessable Entity', detail: 'Too many results' }]) if missing.empty?

        Response.errors(422, missing.map do |name|
          { title: 'Unprocessable Entity', detail: 'Further details required',
            source: { pointer: "/data/attributes/#{name}" } }
        end)
      end

      # Case and spaces do not matter, so "ls1 1ba" matches "LS1 1BA"
      def same?(expected, given)
        normalise(expected) == normalise(given)
      end

      def normalise(value)
        value.to_s.delete(' ').downcase
      end

      def blank?(value)
        value.to_s.strip.empty?
      end
    end
  end
end
