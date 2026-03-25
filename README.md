# HwF DWP API Gem

Ruby client library for communicating with the DWP Citizen API for benefit checks. Handles OAuth2 authentication, mTLS certificate-based communication, citizen matching, citizen data retrieval, and benefit claims lookup.

## Installation

Add to your Gemfile:

```ruby
gem "hwf-dwp-api"
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

Match a citizen against the DWP database. Returns a JSON hash with the citizen's ID on success.

```ruby
response = connection.match_citizen(
  last_name: "Doe",
  date_of_birth: "1955-09-22"
)
response.dig("data", "id")  # => "abc123..."

# With optional params (used for disambiguation)
response = connection.match_citizen(
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

### Get citizen details

Retrieve full citizen data using the ID from `match_citizen`. The ID is stored automatically, so you can call `get_citizen` without arguments after a successful match.

```ruby
# Uses the stored ID from match_citizen
citizen = connection.get_citizen

# Or pass an ID explicitly
citizen = connection.get_citizen("abc123...")

# Access citizen data
citizen.dig("data", "attributes", "nino")               # => "CD345678A"
citizen.dig("data", "attributes", "name", "firstName")   # => "John"
citizen.dig("data", "attributes", "dateOfBirth", "date") # => "1955-09-22"
```

### Get claims

Retrieve benefit claims for a citizen. Uses the stored ID automatically, or pass one explicitly. By default returns only active claims (no end date).

```ruby
# All active claims (uses stored ID)
claims = connection.get_claims

# Filter by benefit type
claims = connection.get_claims(connection.citizen_guid, benefit_type: "pensions_credit")

# Filter by date range
claims = connection.get_claims(connection.citizen_guid,
  effective_from: "2021-01-01",
  effective_to: "2025-12-31"
)

# Access claims data
claims["data"].each do |claim|
  claim.dig("attributes", "benefitType")  # => "pensions_credit"
  claim.dig("attributes", "status")       # => "in_payment"
  claim.dig("attributes", "awards")       # => [{ "startDate" => "2025-04-01", ... }]
end
```

| Filter | Description |
|---|---|
| `benefit_type` | Filter by benefit type (e.g. `pensions_credit`, `universal_credit`) |
| `effective_from` | Start of date range (`YYYY-MM-DD`) |
| `effective_to` | End of date range (`YYYY-MM-DD`) |

Note: The DWP API rotates the citizen ID on each call to `get_citizen` and `get_claims`. The new ID is automatically stored in `connection.citizen_guid` for subsequent requests.

### Full workflow

```ruby
connection = HwfDwpApi.new

# 1. Match citizen
connection.match_citizen(last_name: "Doe", date_of_birth: "1955-09-22")

# 2. Get citizen details (uses stored ID)
citizen = connection.get_citizen

# 3. Get claims (uses rotated ID automatically)
claims = connection.get_claims

# 4. Access the data
puts citizen.dig("data", "attributes", "name")
claims["data"].each do |claim|
  puts "#{claim.dig("attributes", "benefitType")}: #{claim.dig("attributes", "status")}"
end
```

## Error handling

All errors raise `HwfDwpApiError` (or `HwfDwpApiTokenError` for auth issues) with an `error_type` attribute and a JSON-formatted message containing the full API response.

```ruby
begin
  connection.match_citizen(last_name: "Doe", date_of_birth: "1955-09-22")
rescue HwfDwpApiTokenError => e
  # Handle expired/invalid token
  JSON.parse(e.message)  # Full API error response
rescue HwfDwpApiError => e
  parsed = JSON.parse(e.message)

  case e.error_type
  when :not_found          # Citizen not matched / no claims found (404)
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
