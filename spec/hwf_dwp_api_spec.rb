# frozen_string_literal: true

RSpec.describe HwfDwpApi do
  let(:valid_attributes) do
    {
      client_id: 'test-client-id',
      client_secret: 'test-client-secret',
      client_cert: '/path/to/client-cert.pem',
      client_key: '/path/to/client-key.pem',
      context: 'hmcts-hwf',
      policy_id: 'hwf-policy'
    }
  end

  describe '.new' do
    context 'when all mandatory attributes are provided' do
      before do
        allow(HwfDwpApi::Endpoint).to receive(:token).and_return({
                                                                   'access_token' => 'test-token',
                                                                   'expires_in' => 3600
                                                                 })
      end

      it 'returns a Connection instance' do
        expect(described_class.new(valid_attributes)).to be_a(HwfDwpApi::Connection)
      end
    end

    context 'when client_id is missing' do
      it 'raises a validation error' do
        expect do
          described_class.new(valid_attributes.merge(client_id: nil))
        end.to raise_error(HwfDwpApiError, /CLIENT ID is missing/)
      end
    end

    context 'when client_secret is missing' do
      it 'raises a validation error' do
        expect do
          described_class.new(valid_attributes.merge(client_secret: ''))
        end.to raise_error(HwfDwpApiError, /CLIENT SECRET is missing/)
      end
    end

    context 'when client_cert is missing' do
      it 'raises a validation error' do
        expect do
          described_class.new(valid_attributes.merge(client_cert: nil))
        end.to raise_error(HwfDwpApiError, /CLIENT CERT is missing/)
      end
    end

    context 'when client_key is missing' do
      it 'raises a validation error' do
        expect do
          described_class.new(valid_attributes.merge(client_key: nil))
        end.to raise_error(HwfDwpApiError, /CLIENT KEY is missing/)
      end
    end

    context 'when context is missing' do
      it 'raises a validation error' do
        expect do
          described_class.new(valid_attributes.merge(context: ''))
        end.to raise_error(HwfDwpApiError, /CONTEXT is missing/)
      end
    end

    context 'when policy_id is missing' do
      it 'raises a validation error' do
        expect do
          described_class.new(valid_attributes.merge(policy_id: nil))
        end.to raise_error(HwfDwpApiError, /POLICY ID is missing/)
      end
    end

    context 'when access_token is provided without expires_in' do
      it 'raises a validation error' do
        expect do
          described_class.new(valid_attributes.merge(access_token: 'cached-token', expires_in: nil))
        end.to raise_error(HwfDwpApiError, /EXPIRES IN is missing/)
      end
    end

    context 'when attributes are loaded from ENV' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('DWP_CLIENT_ID', nil).and_return('env-client-id')
        allow(ENV).to receive(:fetch).with('DWP_CLIENT_SECRET', nil).and_return('env-client-secret')
        allow(ENV).to receive(:fetch).with('DWP_CLIENT_CERT', nil).and_return('/env/cert.pem')
        allow(ENV).to receive(:fetch).with('DWP_CLIENT_KEY', nil).and_return('/env/key.pem')
        allow(ENV).to receive(:fetch).with('DWP_CONTEXT', nil).and_return('env-context')
        allow(ENV).to receive(:fetch).with('DWP_POLICY_ID', nil).and_return('env-policy')
        allow(ENV).to receive(:fetch).with('DWP_CA_BUNDLE', nil).and_return(nil)
        allow(HwfDwpApi::Endpoint).to receive(:token).and_return({
                                                                   'access_token' => 'test-token',
                                                                   'expires_in' => 3600
                                                                 })
      end

      it 'creates a connection without explicit attributes' do
        expect(described_class.new).to be_a(HwfDwpApi::Connection)
      end

      it 'allows constructor args to override ENV' do
        connection = described_class.new(client_id: 'override-id')
        expect(connection.authentication.instance_variable_get(:@client_id)).to eq('override-id')
      end
    end
  end
end
