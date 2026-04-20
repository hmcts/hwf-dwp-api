# frozen_string_literal: true

RSpec.describe HwfDwpApi::Endpoint do
  before do
    ENV['DWP_API_URL'] = 'https://external-test.integr-dev.dwpcloud.uk:8443'
    described_class.client_cert = nil
    described_class.client_key = nil
    described_class.ca_bundle = nil
  end

  describe 'mTLS options' do
    context 'when credentials are PEM text' do
      let(:cert_pem) { "-----BEGIN CERTIFICATE-----\nMIIB...\n-----END CERTIFICATE-----\n" }
      let(:key_pem) { "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n" }
      let(:ca_pem) { "-----BEGIN CERTIFICATE-----\nMIIC...\n-----END CERTIFICATE-----\n" }

      before do
        described_class.client_cert = cert_pem
        described_class.client_key = key_pem
        described_class.ca_bundle = ca_pem
      end

      it 'uses PEM text directly without reading files' do
        options = described_class.send(:mtls_options)
        expect(options[:pem]).to eq(cert_pem + key_pem)
        expect(options[:ssl_ca_cert]).to eq(ca_pem)
      end
    end

    context 'when credentials are file paths' do
      let(:cert_path) { '/tmp/test-cert.pem' }
      let(:key_path) { '/tmp/test-key.pem' }
      let(:ca_path) { '/tmp/test-ca.pem' }
      let(:cert_content) { "-----BEGIN CERTIFICATE-----\nfile-cert\n-----END CERTIFICATE-----\n" }
      let(:key_content) { "-----BEGIN PRIVATE KEY-----\nfile-key\n-----END PRIVATE KEY-----\n" }
      let(:ca_content) { "-----BEGIN CERTIFICATE-----\nfile-ca\n-----END CERTIFICATE-----\n" }

      before do
        described_class.client_cert = cert_path
        described_class.client_key = key_path
        described_class.ca_bundle = ca_path
        allow(File).to receive(:read).with(cert_path).and_return(cert_content)
        allow(File).to receive(:read).with(key_path).and_return(key_content)
        allow(File).to receive(:read).with(ca_path).and_return(ca_content)
      end

      it 'reads PEM content from files' do
        options = described_class.send(:mtls_options)
        expect(options[:pem]).to eq(cert_content + key_content)
        expect(options[:ssl_ca_cert]).to eq(ca_content)
      end
    end
  end

  describe '.token' do
    let(:token_url) { 'https://external-test.integr-dev.dwpcloud.uk:8443/citizen-information/oauth2/token' }

    context 'when request is successful' do
      before do
        stub_request(:post, token_url)
          .with(body: { client_id: 'test-id', client_secret: 'test-secret', grant_type: 'client_credentials' })
          .to_return(
            status: 200,
            body: { access_token: 'abc123', expires_in: 3600, token_type: 'Bearer' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a hash with access_token' do
        result = described_class.token('test-id', 'test-secret')
        expect(result['access_token']).to eq('abc123')
      end

      it 'returns a hash with expires_in' do
        result = described_class.token('test-id', 'test-secret')
        expect(result['expires_in']).to eq(3600)
      end
    end

    context 'when client_id or secret is wrong' do
      before do
        stub_request(:post, token_url)
          .to_return(
            status: 401,
            body: { error: 'invalid_client', error_description: 'Client authentication failed' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises a HwfDwpApiError with JSON message' do
        expect do
          described_class.token('bad-id', 'bad-secret')
        end.to raise_error(HwfDwpApiError) { |error|
          expect(error.error_type).to eq(:invalid_client)
          parsed = JSON.parse(error.message)
          expect(parsed['error']).to eq('invalid_client')
        }
      end
    end

    context 'when grant_type is wrong' do
      before do
        stub_request(:post, token_url)
          .to_return(
            status: 400,
            body: { error: 'unsupported_grant_type', error_description: 'Grant type not supported' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises a HwfDwpApiError with JSON message' do
        expect do
          described_class.token('test-id', 'test-secret')
        end.to raise_error(HwfDwpApiError) { |error|
          expect(error.error_type).to eq(:unsupported_grant_type)
          parsed = JSON.parse(error.message)
          expect(parsed['error']).to eq('unsupported_grant_type')
        }
      end
    end

    context 'when a required param is missing' do
      before do
        stub_request(:post, token_url)
          .to_return(
            status: 400,
            body: { error: 'invalid_request', error_description: 'Missing required parameter' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises a HwfDwpApiError with JSON message' do
        expect do
          described_class.token('test-id', 'test-secret')
        end.to raise_error(HwfDwpApiError) { |error|
          expect(error.error_type).to eq(:invalid_request)
          parsed = JSON.parse(error.message)
          expect(parsed['error']).to eq('invalid_request')
        }
      end
    end

    context 'when client certificate does not match' do
      before do
        ssl_message = 'SSL_connect returned=1 errno=0 peeraddr=127.0.0.1:4000 state=error: certificate verify failed'
        stub_request(:post, token_url)
          .to_raise(OpenSSL::SSL::SSLError.new(ssl_message))
      end

      it 'raises a HwfDwpApiError with certificate_error type' do
        expect do
          described_class.token('test-id', 'test-secret')
        end.to raise_error(HwfDwpApiError) { |error|
          expect(error.error_type).to eq(:certificate_error)
          expect(error.message).to include('mTLS connection failed')
        }
      end
    end

    context 'when the server is unreachable' do
      before do
        stub_request(:post, token_url).to_raise(Errno::ECONNREFUSED.new('Connection refused - connect(2)'))
      end

      it 'raises a HwfDwpApiError with connection_error type' do
        expect do
          described_class.token('test-id', 'test-secret')
        end.to raise_error(HwfDwpApiError) { |error|
          expect(error.error_type).to eq(:connection_error)
          expect(error.message).to include('Connection refused')
        }
      end
    end

    context 'when server returns 500' do
      before do
        stub_request(:post, token_url)
          .to_return(
            status: 500,
            body: { error: 'server_error', error_description: 'Internal error' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises a HwfDwpApiError with token_error type' do
        expect do
          described_class.token('test-id', 'test-secret')
        end.to raise_error(HwfDwpApiError) { |error|
          expect(error.error_type).to eq(:token_error)
        }
      end
    end
  end
end
