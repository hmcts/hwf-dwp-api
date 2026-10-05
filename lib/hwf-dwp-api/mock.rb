# frozen_string_literal: true

# Answers the gem's HTTP calls from test citizens when DWP_API_CONNECTION=mock_dwp.
# See the "Mock connection" section of the README.
require_relative 'mock/response'
require_relative 'mock/test_citizens'
require_relative 'mock/match'
require_relative 'mock/claims'
require_relative 'mock/responder'
