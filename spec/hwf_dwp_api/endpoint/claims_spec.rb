# frozen_string_literal: true

RSpec.describe HwfDwpApi::Endpoint, 'claims' do
  let(:guid) { 'abc123def456' }
  let(:claims_url) { "https://external-test.integr-dev.dwpcloud.uk:8443/capi/v2/citizens/#{guid}/claims" }
  let(:header_info) do
    {
      access_token: 'test-token',
      correlation_id: '550e8400-e29b-41d4-a716-446655440000',
      context: 'hmcts-hwf',
      policy_id: 'hwf-policy'
    }
  end

  before do
    ENV['DWP_API_URL'] = 'https://external-test.integr-dev.dwpcloud.uk:8443'
    described_class.client_cert = nil
    described_class.client_key = nil
    described_class.ca_bundle = nil
  end

  context 'when claims are found' do
    let(:response_body) do
      {
        data: [
          {
            id: 'pensions_credit_0',
            type: 'Claim',
            attributes: {
              guid: 'new-guid-789',
              benefitType: 'pensions_credit',
              startDate: '2021-10-01',
              status: 'in_payment',
              awards: [{ startDate: '2025-04-01', status: 'live', amount: 21_856 }]
            }
          }
        ],
        links: { self: '/capi/v2/citizens/new-guid-789/claims' }
      }
    end

    before do
      stub_request(:get, claims_url)
        .to_return(
          status: 200,
          body: response_body.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns the claims data' do
      result = described_class.claims(guid, header_info)
      expect(result['data'].length).to eq(1)
      expect(result.dig('data', 0, 'attributes', 'benefitType')).to eq('pensions_credit')
    end
  end

  context 'when filtering by benefit type' do
    before do
      stub_request(:get, claims_url)
        .with(query: { 'benefitType' => 'pensions_credit' })
        .to_return(
          status: 200,
          body: { data: [] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'sends benefit_type as query param' do
      described_class.claims(guid, header_info, benefit_type: 'pensions_credit')
      expect(WebMock).to have_requested(:get, claims_url)
        .with(query: { 'benefitType' => 'pensions_credit' })
    end
  end

  context 'when filtering by date range' do
    before do
      stub_request(:get, claims_url)
        .with(query: { 'effectiveFromDate' => '2021-01-01', 'effectiveToDate' => '2025-12-31' })
        .to_return(
          status: 200,
          body: { data: [] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'sends date filters as query params' do
      described_class.claims(guid, header_info, effective_from: '2021-01-01', effective_to: '2025-12-31')
      expect(WebMock).to have_requested(:get, claims_url)
        .with(query: { 'effectiveFromDate' => '2021-01-01', 'effectiveToDate' => '2025-12-31' })
    end
  end

  context 'when no claims are found' do
    before do
      stub_request(:get, claims_url)
        .to_return(
          status: 404,
          body: {
            errors: [{ status: '404', title: 'No Resource Found',
                       detail: 'No claims found for the supplied criteria' }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'raises HwfDwpApiError with JSON message' do
      expect do
        described_class.claims(guid, header_info)
      end.to raise_error(HwfDwpApiError) { |error|
        expect(error.error_type).to eq(:not_found)
        parsed = JSON.parse(error.message)
        expect(parsed.dig('errors', 0, 'detail')).to include('No claims found')
      }
    end
  end

  context 'when benefit type is invalid' do
    before do
      stub_request(:get, claims_url)
        .with(query: { 'benefitType' => 'invalid_type' })
        .to_return(
          status: 400,
          body: {
            errors: [{ status: '400', title: 'Bad Request',
                       detail: "Invalid benefitType: 'invalid_type'" }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'raises HwfDwpApiError with bad_request type' do
      expect do
        described_class.claims(guid, header_info, benefit_type: 'invalid_type')
      end.to raise_error(HwfDwpApiError) { |error|
        expect(error.error_type).to eq(:bad_request)
      }
    end
  end

  context 'when token is expired' do
    before do
      stub_request(:get, claims_url)
        .to_return(
          status: 401,
          body: {
            errors: [{ status: '401', title: 'Unauthorized',
                       detail: 'Invalid or expired JWT token' }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'raises HwfDwpApiTokenError with invalid_token type' do
      expect do
        described_class.claims(guid, header_info)
      end.to raise_error(HwfDwpApiTokenError) { |error|
        expect(error.error_type).to eq(:invalid_token)
      }
    end
  end

  context 'when TLS certificate does not match' do
    before do
      stub_request(:get, claims_url)
        .to_raise(OpenSSL::SSL::SSLError.new('certificate verify failed'))
    end

    it 'raises HwfDwpApiError with certificate_error type' do
      expect do
        described_class.claims(guid, header_info)
      end.to raise_error(HwfDwpApiError) { |error|
        expect(error.error_type).to eq(:certificate_error)
      }
    end
  end
end
