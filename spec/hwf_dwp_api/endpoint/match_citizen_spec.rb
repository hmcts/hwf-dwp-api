# frozen_string_literal: true

RSpec.describe HwfDwpApi::Endpoint, "match_citizen" do
  let(:match_url) { "https://external-test.integr-dev.dwpcloud.uk:8443/capi/v2/citizens/match" }
  let(:header_info) do
    {
      access_token: "test-token",
      correlation_id: "550e8400-e29b-41d4-a716-446655440000",
      context: "hmcts-hwf",
      policy_id: "hwf-policy"
    }
  end
  let(:citizen_params) do
    { last_name: "Doe", date_of_birth: "1955-09-22" }
  end

  before do
    ENV["DWP_API_URL"] = "https://external-test.integr-dev.dwpcloud.uk:8443"
    described_class.client_cert = nil
    described_class.client_key = nil
    described_class.ca_bundle = nil
  end

  context "when citizen is matched" do
    before do
      stub_request(:post, match_url)
        .to_return(
          status: 200,
          body: {
            data: {
              id: "guid-123",
              type: "MatchResult",
              attributes: { matchingScenario: "scenario_1" }
            }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "returns the full JSON response" do
      result = described_class.match_citizen(citizen_params, header_info)
      expect(result).to eq({
        "data" => {
          "id" => "guid-123",
          "type" => "MatchResult",
          "attributes" => { "matchingScenario" => "scenario_1" }
        }
      })
    end

    it "sends the correct request body" do
      described_class.match_citizen(citizen_params, header_info)
      expect(WebMock).to have_requested(:post, match_url)
        .with(body: {
          data: {
            type: "Match",
            attributes: { lastName: "Doe", dateOfBirth: "1955-09-22" }
          }
        })
    end

    it "includes optional params when provided" do
      full_params = citizen_params.merge(first_name: "John", nino_fragment: "3456", postcode: "M1 1AA")
      described_class.match_citizen(full_params, header_info)
      expect(WebMock).to have_requested(:post, match_url)
        .with(body: {
          data: {
            type: "Match",
            attributes: {
              lastName: "Doe",
              dateOfBirth: "1955-09-22",
              firstName: "John",
              ninoFragment: "3456",
              postcode: "M1 1AA"
            }
          }
        })
    end
  end

  context "when citizen is not found" do
    before do
      stub_request(:post, match_url)
        .to_return(
          status: 404,
          body: {
            errors: [{ status: "404", title: "No Resource Found",
                       detail: "Unable to find a unique match for the supplied matching dataset" }]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "raises HwfDwpApiError with not_found type" do
      expect {
        described_class.match_citizen(citizen_params, header_info)
      }.to raise_error(HwfDwpApiError) { |error|
        expect(error.error_type).to eq(:not_found)
      }
    end
  end

  context "when disambiguation is needed" do
    before do
      stub_request(:post, match_url)
        .to_return(
          status: 422,
          body: {
            errors: [{ status: "422", title: "Unprocessable Entity",
                       detail: "Further details required",
                       source: { pointer: "/data/attributes/ninoFragment" } }]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "raises HwfDwpApiError with unprocessable type" do
      expect {
        described_class.match_citizen(citizen_params, header_info)
      }.to raise_error(HwfDwpApiError) { |error|
        expect(error.error_type).to eq(:unprocessable)
        expect(error.message).to include("Further details required")
      }
    end
  end

  context "when request body is invalid" do
    before do
      stub_request(:post, match_url)
        .to_return(
          status: 400,
          body: {
            errors: [{ status: "400", title: "Bad Request",
                       detail: "lastName is required" }]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "raises HwfDwpApiError with bad_request type" do
      expect {
        described_class.match_citizen({ last_name: nil, date_of_birth: "1955-09-22" }, header_info)
      }.to raise_error(HwfDwpApiError) { |error|
        expect(error.error_type).to eq(:bad_request)
      }
    end
  end

  context "when token is expired" do
    before do
      stub_request(:post, match_url)
        .to_return(
          status: 401,
          body: {
            errors: [{ status: "401", title: "Unauthorized",
                       detail: "Invalid or expired JWT token" }]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "raises HwfDwpApiTokenError with invalid_token type" do
      expect {
        described_class.match_citizen(citizen_params, header_info)
      }.to raise_error(HwfDwpApiTokenError) { |error|
        expect(error.error_type).to eq(:invalid_token)
      }
    end
  end

  context "when TLS certificate does not match" do
    before do
      stub_request(:post, match_url).to_raise(OpenSSL::SSL::SSLError.new("certificate verify failed"))
    end

    it "raises HwfDwpApiError with certificate_error type" do
      expect {
        described_class.match_citizen(citizen_params, header_info)
      }.to raise_error(HwfDwpApiError) { |error|
        expect(error.error_type).to eq(:certificate_error)
      }
    end
  end
end
