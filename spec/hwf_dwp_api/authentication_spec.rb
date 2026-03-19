# frozen_string_literal: true

RSpec.describe HwfDwpApi::Authentication do
  let(:token_response) do
    {
      "access_token" => "test-access-token-123",
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
    context "without cached token" do
      it "fetches a new token from the API" do
        described_class.new(connection_attributes)
        expect(HwfDwpApi::Endpoint).to have_received(:token).with("test-client-id", "test-client-secret")
      end

      it "sets the access_token" do
        auth = described_class.new(connection_attributes)
        expect(auth.access_token).to eq("test-access-token-123")
      end

      it "sets the expires_in" do
        auth = described_class.new(connection_attributes)
        expect(auth.expires_in).to be_a(Time)
      end
    end

    context "with cached token" do
      let(:future_time) { Time.now + 3600 }
      let(:cached_attributes) do
        connection_attributes.merge(
          access_token: "cached-token",
          expires_in: future_time
        )
      end

      it "uses the cached token" do
        auth = described_class.new(cached_attributes)
        expect(auth.access_token).to eq("cached-token")
      end

      it "does not call the token endpoint" do
        described_class.new(cached_attributes)
        expect(HwfDwpApi::Endpoint).not_to have_received(:token)
      end
    end
  end

  describe "#token" do
    it "returns the access token" do
      auth = described_class.new(connection_attributes)
      expect(auth.token).to eq("test-access-token-123")
    end

    context "when token has expired" do
      let(:renewed_response) do
        {
          "access_token" => "renewed-token-456",
          "expires_in" => 3600,
          "token_type" => "Bearer"
        }
      end

      it "fetches a new token" do
        auth = described_class.new(connection_attributes)
        Timecop.travel(Time.now + 4000)
        allow(HwfDwpApi::Endpoint).to receive(:token).and_return(renewed_response)

        expect(auth.token).to eq("renewed-token-456")
        Timecop.return
      end
    end
  end

  describe "#expired?" do
    it "returns false when token is fresh" do
      auth = described_class.new(connection_attributes)
      expect(auth.expired?).to be false
    end

    it "returns true when token has expired" do
      auth = described_class.new(connection_attributes)
      Timecop.travel(Time.now + 4000)
      expect(auth.expired?).to be true
      Timecop.return
    end

    it "returns true when token is about to expire within 100 seconds" do
      auth = described_class.new(connection_attributes)
      Timecop.travel(Time.now + 3550)
      expect(auth.expired?).to be true
      Timecop.return
    end
  end

  describe "#get_token" do
    it "calls the token endpoint" do
      auth = described_class.new(connection_attributes)
      auth.get_token
      expect(HwfDwpApi::Endpoint).to have_received(:token).twice
    end

    it "updates the access_token" do
      auth = described_class.new(connection_attributes)
      allow(HwfDwpApi::Endpoint).to receive(:token).and_return({
        "access_token" => "new-token",
        "expires_in" => 7200
      })
      auth.get_token
      expect(auth.access_token).to eq("new-token")
    end
  end
end
