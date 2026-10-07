# frozen_string_literal: true

require 'net/http'

module HwfDwpApi
  module Mock
    # A test citizen with `simulate_failure` makes the mock fail the way DWP or
    # the network would when they are matched. The gem's normal error handling
    # then turns it into the same HwfDwpApiError a real failure gives.
    module Failures
      KINDS = %w[timeout dns connection_reset gateway_error].freeze

      module_function

      def response(kind)
        case kind
        when 'timeout' then raise Net::OpenTimeout, 'execution expired'
        when 'dns' then raise SocketError, 'getaddrinfo: Name or service not known'
        when 'connection_reset' then raise Errno::ECONNRESET, 'Connection reset by peer'
        when 'gateway_error' then Response.new(502, '<html><body><h1>502 Bad Gateway</h1></body></html>')
        else raise ArgumentError, "Unknown simulate_failure #{kind.inspect}, expected one of #{KINDS.join(', ')}"
        end
      end
    end
  end
end
