# frozen_string_literal: true

RSpec.describe HwfDwpApi::Endpoint do
  before do
    ENV["DWP_API_URL"] = "https://external-test.integr-dev.dwpcloud.uk:8443/capi"
    described_class.client_cert = nil
    described_class.client_key = nil
    described_class.ca_bundle = nil
  end

  describe ".token" do
    let(:token_url) { "https://external-test.integr-dev.dwpcloud.uk:8443/capi/oauth2/token" }

    context "when request is successful" do
      before do
        stub_request(:post, token_url)
          .with(body: { client_id: "test-id", client_secret: "test-secret", grant_type: "client_credentials" })
          .to_return(
            status: 200,
            body: { access_token: "abc123", expires_in: 3600, token_type: "Bearer" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns a hash with access_token" do
        result = described_class.token("test-id", "test-secret")
        expect(result["access_token"]).to eq("abc123")
      end

      it "returns a hash with expires_in" do
        result = described_class.token("test-id", "test-secret")
        expect(result["expires_in"]).to eq(3600)
      end
    end

    context "when credentials are invalid" do
      before do
        stub_request(:post, token_url)
          .to_return(
            status: 401,
            body: { error: "invalid_client", error_description: "Client authentication failed" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises a HwfDwpApiError with token_error type" do
        expect {
          described_class.token("bad-id", "bad-secret")
        }.to raise_error(HwfDwpApiError) { |error|
          expect(error.error_type).to eq(:token_error)
        }
      end
    end

    context "when server returns 500" do
      before do
        stub_request(:post, token_url)
          .to_return(
            status: 500,
            body: { error: "server_error", error_description: "Internal error" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises a HwfDwpApiError" do
        expect {
          described_class.token("test-id", "test-secret")
        }.to raise_error(HwfDwpApiError)
      end
    end
  end
end
