# frozen_string_literal: true

RSpec.describe HwfDwpApi::Endpoint, 'citizen' do
  let(:guid) { 'abc123def456' }
  let(:citizen_url) { "https://external-test.integr-dev.dwpcloud.uk:8443/capi/v2/citizens/#{guid}" }
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

  context 'when citizen is found' do
    let(:response_body) do
      {
        data: {
          id: 'new-guid-789',
          type: 'Citizen',
          attributes: {
            guid: 'new-guid-789',
            nino: 'CD345678A',
            sex: 'M',
            name: { title: 'Mr', firstName: 'John', lastName: 'Doe' },
            dateOfBirth: { date: '1955-09-22' }
          }
        },
        links: { self: '/capi/v2/citizens/new-guid-789' }
      }
    end

    before do
      stub_request(:get, citizen_url)
        .to_return(
          status: 200,
          body: response_body.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns citizen data with id' do
      result = described_class.citizen(guid, header_info)
      expect(result.dig('data', 'id')).to eq('new-guid-789')
    end

    it 'includes citizen attributes' do
      result = described_class.citizen(guid, header_info)
      attrs = result.dig('data', 'attributes')
      expect(attrs['nino']).to eq('CD345678A')
      expect(attrs.dig('name', 'firstName')).to eq('John')
    end
  end

  context 'when citizen is not found' do
    before do
      stub_request(:get, citizen_url)
        .to_return(
          status: 404,
          body: {
            errors: [{ status: '404', title: 'No Resource Found',
                       detail: 'No citizen found for the supplied GUID' }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'raises HwfDwpApiError with JSON message' do
      expect do
        described_class.citizen(guid, header_info)
      end.to raise_error(HwfDwpApiError) { |error|
        expect(error.error_type).to eq(:not_found)
        parsed = JSON.parse(error.message)
        expect(parsed.dig('errors', 0, 'detail')).to include('No citizen found')
      }
    end
  end

  context 'when token is expired' do
    before do
      stub_request(:get, citizen_url)
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
        described_class.citizen(guid, header_info)
      end.to raise_error(HwfDwpApiTokenError) { |error|
        expect(error.error_type).to eq(:invalid_token)
      }
    end
  end

  context 'when TLS certificate does not match' do
    before do
      stub_request(:get, citizen_url)
        .to_raise(OpenSSL::SSL::SSLError.new('certificate verify failed'))
    end

    it 'raises HwfDwpApiError with certificate_error type' do
      expect do
        described_class.citizen(guid, header_info)
      end.to raise_error(HwfDwpApiError) { |error|
        expect(error.error_type).to eq(:certificate_error)
      }
    end
  end
end
