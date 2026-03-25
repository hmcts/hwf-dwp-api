# HwF DWP API Gem

Ruby client library for communicating with the DWP Citizen API for benefit checks. Handles OAuth2 authentication, mTLS certificate-based communication, and citizen matching.

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
| `DWP_API_URL` | Yes | Root URL of the DWP API (e.g. `https://localhost:4000`) |
| `DWP_CLIENT_ID` | Yes | OAuth2 client ID |
| `DWP_CLIENT_SECRET` | Yes | OAuth2 client secret |
| `DWP_CLIENT_CERT` | Yes | Path to PEM client certificate for mTLS |
| `DWP_CLIENT_KEY` | Yes | Path to PEM private key for mTLS |
| `DWP_CONTEXT` | Yes | Provisioned source system identifier (e.g. `hmcts-hwf`) |
| `DWP_POLICY_ID` | Yes | Agreed matching policy ID (e.g. `hwf-policy`) |
| `DWP_CA_BUNDLE` | No | Path to CA bundle PEM for mTLS certificate validation |

All attributes can also be passed directly to `HwfDwpApi.new`, which takes precedence over ENV values.

## Usage

### Connect

```ruby
# Using ENV variables
connection = HwfDwpApi.new

# Or with explicit attributes
connection = HwfDwpApi.new(
  client_id: "my-client-id",
  client_secret: "my-client-secret",
  client_cert: "/path/to/cert.pem",
  client_key: "/path/to/key.pem",
  context: "hmcts-hwf",
  policy_id: "hwf-policy"
)

# Or with a cached token
connection = HwfDwpApi.new(
  access_token: "cached-token",
  expires_in: Time.now + 3600
)
```

### Match citizen

To look up a citizen, call `match_citizen` with their details. Returns a GUID string on success.

```ruby
# Required params only
guid = connection.match_citizen(
  last_name: "Doe",
  date_of_birth: "1955-09-22"
)

# With optional params (used for disambiguation)
guid = connection.match_citizen(
  last_name: "Smith",
  date_of_birth: "1985-06-15",
  first_name: "Jane",
  nino_fragment: "1234",
  postcode: "SW1A 1AA"
)
```

| Parameter | Required | Description |
|---|---|---|
| `last_name` | Yes | Citizen's last name (max 35 chars) |
| `date_of_birth` | Yes | Date of birth in `YYYY-MM-DD` format |
| `first_name` | No | First name (max 70 chars) |
| `nino_fragment` | No | Last 4 digits of NINO, excluding suffix |
| `postcode` | No | UK postcode (max 8 chars) |

## Error handling

All errors raise `HwfDwpApiError` (or `HwfDwpApiTokenError` for auth issues) with an `error_type` attribute for programmatic handling.

```ruby
begin
  connection.match_citizen(last_name: "Doe", date_of_birth: "1955-09-22")
rescue HwfDwpApiTokenError => e
  # Handle expired/invalid token
rescue HwfDwpApiError => e
  case e.error_type
  when :not_found          # Citizen not matched (404)
  when :unprocessable      # Disambiguation needed (422)
  when :bad_request        # Invalid request params (400)
  when :invalid_client     # Wrong client_id or secret (401)
  when :certificate_error  # mTLS certificate mismatch
  when :connection_error   # Server unreachable
  end
end
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
