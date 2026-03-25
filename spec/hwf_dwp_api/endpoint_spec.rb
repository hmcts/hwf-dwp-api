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

    context "when client_id or secret is wrong" do
      before do
        stub_request(:post, token_url)
          .to_return(
            status: 401,
            body: { error: "invalid_client", error_description: "Client authentication failed" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises a HwfDwpApiError with invalid_client type" do
        expect {
          described_class.token("bad-id", "bad-secret")
        }.to raise_error(HwfDwpApiError) { |error|
          expect(error.error_type).to eq(:invalid_client)
          expect(error.message).to include("invalid_client")
        }
      end
    end

    context "when grant_type is wrong" do
      before do
        stub_request(:post, token_url)
          .to_return(
            status: 400,
            body: { error: "unsupported_grant_type", error_description: "Grant type not supported" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises a HwfDwpApiError with unsupported_grant_type type" do
        expect {
          described_class.token("test-id", "test-secret")
        }.to raise_error(HwfDwpApiError) { |error|
          expect(error.error_type).to eq(:unsupported_grant_type)
          expect(error.message).to include("unsupported_grant_type")
        }
      end
    end

    context "when a required param is missing" do
      before do
        stub_request(:post, token_url)
          .to_return(
            status: 400,
            body: { error: "invalid_request", error_description: "Missing required parameter" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "raises a HwfDwpApiError with invalid_request type" do
        expect {
          described_class.token("test-id", "test-secret")
        }.to raise_error(HwfDwpApiError) { |error|
          expect(error.error_type).to eq(:invalid_request)
          expect(error.message).to include("invalid_request")
        }
      end
    end

    context "when client certificate does not match" do
      before do
        stub_request(:post, token_url).to_raise(OpenSSL::SSL::SSLError.new("SSL_connect returned=1 errno=0 peeraddr=127.0.0.1:4000 state=error: certificate verify failed"))
      end

      it "raises a HwfDwpApiError with certificate_error type" do
        expect {
          described_class.token("test-id", "test-secret")
        }.to raise_error(HwfDwpApiError) { |error|
          expect(error.error_type).to eq(:certificate_error)
          expect(error.message).to include("mTLS connection failed")
        }
      end
    end

    context "when the server is unreachable" do
      before do
        stub_request(:post, token_url).to_raise(Errno::ECONNREFUSED.new("Connection refused - connect(2)"))
      end

      it "raises a HwfDwpApiError with connection_error type" do
        expect {
          described_class.token("test-id", "test-secret")
        }.to raise_error(HwfDwpApiError) { |error|
          expect(error.error_type).to eq(:connection_error)
          expect(error.message).to include("Connection refused")
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

      it "raises a HwfDwpApiError with token_error type" do
        expect {
          described_class.token("test-id", "test-secret")
        }.to raise_error(HwfDwpApiError) { |error|
          expect(error.error_type).to eq(:token_error)
        }
      end
    end
  end
end
