# HwF DWP API Gem

Ruby client library for communicating with the DWP Citizen API for benefit checks. Handles OAuth2 authentication and mTLS certificate-based communication.

## Installation

Add to your Gemfile:

```ruby
gem "hwf_dwp_api"
```

## Configuration

The gem reads connection attributes from environment variables. Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

### Environment variables

| Variable | Required | Description |
|---|---|---|
| `DWP_API_URL` | Yes | Base URL of the DWP API |
| `DWP_CLIENT_ID` | Yes | OAuth2 client ID |
| `DWP_CLIENT_SECRET` | Yes | OAuth2 client secret |
| `DWP_CLIENT_CERT` | Yes | Path to PEM client certificate for mTLS |
| `DWP_CLIENT_KEY` | Yes | Path to PEM private key for mTLS |
| `DWP_CONTEXT` | Yes | Provisioned source system identifier (e.g. `hmcts-hwf`) |
| `DWP_POLICY_ID` | Yes | Agreed matching policy ID (e.g. `hwf-policy`) |
| `DWP_CA_BUNDLE` | No | Path to CA bundle PEM for mTLS certificate validation |

All attributes can also be passed directly to `HwfDwpApi.new`, which takes precedence over ENV values.

## Usage

### With ENV variables configured

```ruby
connection = HwfDwpApi.new
connection.access_token
connection.header_info(SecureRandom.uuid)
```

### With explicit attributes

```ruby
connection = HwfDwpApi.new(
  client_id: "my-client-id",
  client_secret: "my-client-secret",
  client_cert: "/path/to/cert.pem",
  client_key: "/path/to/key.pem",
  context: "hmcts-hwf",
  policy_id: "hwf-policy"
)
```

### With a cached token

```ruby
connection = HwfDwpApi.new(
  access_token: "cached-token",
  expires_in: Time.now + 3600
)
```

## Development

```bash
bundle install
cp .env.example .env
# Edit .env with your values
bundle exec rspec
```

### Console

```bash
bundle exec irb -r dotenv/load -r hwf_dwp_api
```

## License

MIT
