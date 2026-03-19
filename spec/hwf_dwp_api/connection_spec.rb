# frozen_string_literal: true

RSpec.describe HwfDwpApi::Connection do
  let(:token_response) do
    {
      "access_token" => "test-access-token",
      "expires_in" => 3600,
      "token_type" => "Bearer"
    }
  end

  let(:connection_attributes) do
    {
      client_id: "test-client-id",
      client_secret: "test-client-secret",
      client_cert: "/path/to/client-cert.pem",
      client_key: "/path/to/client-key.pem",
      context: "hmcts-hwf",
      policy_id: "hwf-policy"
    }
  end

  before do
    allow(HwfDwpApi::Endpoint).to receive(:token).and_return(token_response)
  end

  describe "#initialize" do
    it "creates an Authentication instance" do
      connection = described_class.new(connection_attributes)
      expect(connection.authentication).to be_a(HwfDwpApi::Authentication)
    end
  end

  describe "#access_token" do
    it "returns the access token from authentication" do
      connection = described_class.new(connection_attributes)
      expect(connection.access_token).to eq("test-access-token")
    end
  end

  describe "#header_info" do
    it "returns a hash with all required DWP headers" do
      connection = described_class.new(connection_attributes)
      correlation_id = "550e8400-e29b-41d4-a716-446655440000"

      result = connection.header_info(correlation_id)

      expect(result).to eq({
        access_token: "test-access-token",
        correlation_id: "550e8400-e29b-41d4-a716-446655440000",
        context: "hmcts-hwf",
        policy_id: "hwf-policy"
      })
    end
  end
end
