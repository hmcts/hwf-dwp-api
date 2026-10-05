# frozen_string_literal: true

module HwfDwpApi
  module Mock
    # Builds the claims response for a test citizen
    module Claims
      module_function

      # query: the query string hash of the claims request
      def response(guid, query)
        citizen = TestCitizens.find_by_guid(guid)
        return Response.not_found('No citizen found for the supplied GUID') if citizen.nil?

        claims = select_claims(citizen['claims'] || [], query.transform_keys(&:to_s))
        return Response.not_found('No claims found for the supplied criteria') if claims.empty?

        data = claims.each_with_index.map { |claim, index| claim_data(claim, index, guid) }
        Response.data(data, self: "/capi/v2/citizens/#{guid}/claims")
      end

      def select_claims(claims, query)
        benefit_types = Array(query['benefitType'])
        claims = claims.select { |claim| benefit_types.include?(claim['benefitType']) } unless benefit_types.empty?

        in_window(claims, date(query['effectiveFromDate']), date(query['effectiveToDate']))
      end

      # DWP returns the claims live inside the window, or only open claims when there is no window
      def in_window(claims, window_from, window_to)
        return claims.select { |claim| date(claim['endDate']).nil? } if window_from.nil? && window_to.nil?

        claims.reject { |claim| ended_before?(claim, window_from) || started_after?(claim, window_to) }
      end

      def ended_before?(claim, window_from)
        end_date = date(claim['endDate'])
        !window_from.nil? && !end_date.nil? && end_date < window_from
      end

      def started_after?(claim, window_to)
        start_date = date(claim['startDate'])
        !window_to.nil? && !start_date.nil? && start_date > window_to
      end

      def claim_data(claim, index, guid)
        attributes = claim['_empty_attributes'] ? {} : { 'guid' => guid }.merge(claim.except('id'))

        { id: (claim['id'] || "#{claim['benefitType']}_#{index}").to_s, type: 'Claim', attributes: attributes }
      end

      def date(value)
        Date.parse(value.to_s) unless value.to_s.empty?
      end
    end
  end
end
