# frozen_string_literal: true

module HwfDwpApi
  module Mock
    # A test citizen with `simulate_claims_error` is matched as normal, then
    # get_claims answers with that DWP error code. With `claims_error_times: N`
    # it fails N times and then returns the claims. See CHANGELOG.md
    module ClaimsErrors
      # Each code's error exactly as production DWP sent it, and the HTTP status it is sent with
      ERRORS = {
        '2000' => {
          status: 500,
          error: {
            code: '2000',
            detail: 'Internal server error / failure. Please retry your request',
            id: '1-72436ad4-6350-42ce-b958-d002131e7f8c',
            status: '500',
            title: 'Internal server error / failure. Please retry your request'
          }
        },
        '2001' => {
          status: 422,
          error: {
            code: '2001',
            detail: 'Unexpected multiple active claim records exists. Please log a request with the DWP support.',
            id: '1f41c854-fbfd-4849-b293-7333791004b8-universal_credit',
            status: '422',
            title: 'Unprocessable Content - The request was well-formed but was unable to be performed ' \
                   'due to data error.'
          }
        },
        '1007' => {
          status: 500,
          error: {
            code: '1007',
            detail: 'The service could not resolve a claimant from the parameters supplied',
            id: '1-ff706b7f-c3d6-4efa-a886-2a0e4785e173',
            status: '500',
            title: 'Internal server error / failure. Please retry your request'
          }
        }
      }.freeze

      module_function

      # The error response, or nil when the claims should be returned
      def response(citizen)
        code = citizen['simulate_claims_error']
        return nil if code.nil? || failed_enough_times?(citizen)

        error = ERRORS.fetch(code) { raise ArgumentError, "Unknown simulate_claims_error #{code.inspect}" }
        Response.json(error[:status], errors: [error[:error]])
      end

      # Counts the failures per citizen; the count starts again once the claims are returned
      def failed_enough_times?(citizen)
        times = citizen['claims_error_times']
        return false if times.nil?

        id = citizen['internal_id']
        if failures[id] >= times
          failures.delete(id)
          return true
        end

        failures[id] += 1
        false
      end

      def failures
        @failures ||= Hash.new(0)
      end

      def reset!
        @failures = nil
      end
    end
  end
end
