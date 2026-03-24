# frozen_string_literal: true

require "dotenv/load"
require "hwf_dwp_api"
require "pry"
require "vcr"
require "timecop"
require "webmock/rspec"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  WebMock.disable_net_connect!(allow_localhost: true)

  Dir["./spec/support/**/*.rb"].each { |f| require f }
  ENV["DWP_API_URL"] = "https://external-test.integr-dev.dwpcloud.uk:8443/capi"
end

VCR.configure do |c|
  c.cassette_library_dir = "spec/cassettes"
  c.hook_into :webmock
  c.ignore_localhost = true
  c.before_record do |i|
    i.response.body.force_encoding("UTF-8")
  end
end
