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
| `DWP_API_CONNECTION` | No | `mock_dwp` answers from test citizens instead of calling DWP (see [Mock connection](#mock-connection)). Any other value, or none, uses the real connection |

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
citizen.dig("data", "attributes", "dateOfDeath", "date") # => "2005-09-22"
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

## Mock connection

Set `DWP_API_CONNECTION=mock_dwp` to test scenarios without calling DWP. The gem is used exactly as with a real connection; every HTTP call is answered from the test citizens in `lib/hwf-dwp-api/mock/citizens` instead, and the usual response and error handling still runs. Any other value, or none, uses the real connection.

- None of the `DWP_*` connection variables are needed; a fake token is issued.
- A warning is logged each time a connection is created, and every guid starts with `mock-dwp-`.
- `match_citizen` needs the last name and date of birth of a test citizen. First name, NI number fragment and postcode are checked when both sides have them. No match raises `:not_found`; more than one raises `:unprocessable`.
- `get_claims` returns the citizen's claims that were live inside the date window, or only open claims when no window is given. No claims raises `:not_found`.
- Rate limiting is not mocked.

To add a scenario, add a YAML file to `lib/hwf-dwp-api/mock/citizens` with a unique `internal_id`. Never set `mock_dwp` in production.

### Test citizens

The outcome is what the HwF staff app returns for each citizen, checked on 05/10/2026 for every application date from 2020 to mid-2027. Dates are shown as dd/mm/yyyy, the way they are typed into the staff app; `match_citizen` itself takes `YYYY-MM-DD`.

| Group | Name | DOB | NI number | Postcode | Claim | Outcome | Yes when application date is | Notes |
|---|---|---|---|---|---|---|---|---|
| General | Michael Clarke | 15/01/1990 | JC113456A | NE6 1EA | Universal Credit, in payment from 01/06/2024 | Yes | 01/06/2024 onwards | |
| General | Jane Smith | 15/06/1985 | AB789012D | SW1A 1AA | Income Support, in payment from 01/03/2023 | Yes | 01/03/2023 onwards | Same surname and DOB as Janet Smith |
| General | Janet Smith | 15/06/1985 | JC124455A | E1 6AN | Pension Credit, in payment from 01/01/2024 | Yes | 01/01/2024 onwards | Same surname and DOB as Jane Smith |
| General | John Doe | 22/09/1955 | JC123456A | M1 1AA | Pension Credit, in payment from 01/10/2021 | Yes | 01/10/2021 onwards | |
| General | Sarah Williams | 03/12/1978 | JC129012A | LS1 1BA | ESA (income-based), in payment from 15/07/2022 | Yes | 15/07/2022 onwards | |
| General | Robert Brown | 18/04/1992 | JC125678A | B1 1BB | JSA (income-based), in payment from 10/01/2025 | Yes | 10/01/2025 onwards | |
| General | Olivia Hughes | 22/08/1991 | JC127841A | M1 1AA | Universal Credit, in payment from 15/01/2025 | Yes | 15/01/2025 onwards | Rate-limited on the mock server; behaves normally here |
| General | Mary Jones | 30/07/1988 | JC121234A | CF10 1AA | No claims | No | Never | Matched, but has no claims |
| General | Peter Wilson | 08/11/1982 | JC122345A | E14 5AB | Income Support, returned with no details | No | Never | Claim has empty attributes |
| General | David Taylor | 14/02/1975 | JC128901A | L1 1AA | Income Support, closed 01/01/2022 to 30/06/2024<br>Universal Credit, closed 01/09/2024 to 31/01/2025 | No | Never | Both claims closed |
| Date window | Hannah Foster | 12/03/1987 | JC112233A | BS1 4DJ | Universal Credit, in payment from 14/09/2026 | Yes | 14/09/2026 onwards | No on 13/09/2026 or earlier |
| Date window | Daniel Reed | 05/10/1979 | JC223344B | NG1 5FS | Universal Credit, closed 01/08/2025 to 14/09/2026 | No | Never | Closed claim |
| Date window | Priya Shah | 27/05/1993 | JC334466C | LE1 6TP | Income Support, closed 01/05/2025 to 21/08/2026 | No | Never | Closed claim |
| Date window | Tom Bennett | 19/08/1984 | JC445577D | S1 2HE | Income Support, closed 03/02/2025 to 10/09/2026<br>Universal Credit, in payment from 11/09/2026 | Yes | 11/09/2026 onwards | No on 10/09/2026 or earlier |
| RST-8365 | Amelia Hart | 11/02/1990 | JC836501A | LS1 4AP | Universal Credit, active 01/06/2026 to 30/06/2026 | Yes | 01/06/2026 to 09/08/2026 | Same with RST-8365 |
| RST-8365 | Brian Okafor | 23/07/1985 | JC836502B | M4 5BD | Universal Credit, closed 01/06/2026 to 30/06/2026 | No | Never | Same with RST-8365 |
| RST-8365 | Chloe Marsh | 02/11/1994 | JC836503C | B2 4QA | Universal Credit, active 01/06/2026 to 30/06/2026, take-home pay £500 | Yes | 01/06/2026 to 09/08/2026 | Becomes No with RST-8365 (take-home pay £500) |
| RST-8365 | Derek Nolan | 17/04/1978 | JC836504D | CF10 3AT | Universal Credit, active 01/06/2026 to 30/06/2026, £0 paid | Yes | 01/06/2026 to 09/08/2026 | Becomes No with RST-8365 (£0 paid) |
| RST-8365 | Erin Vasquez | 30/09/1989 | JC836505A | NE1 7RU | Universal Credit, suspended 01/06/2026 to 30/06/2026 | No | Never | Same with RST-8365 |
| RST-8365 | Farid Rahman | 26/01/1982 | JC836506B | BD1 1HY | JSA (income-based), active from 01/03/2026 | Yes | 01/03/2026 onwards | Same with RST-8365 |
| RST-8365 | Grace Pemberton | 08/06/1996 | JC836507C | EX1 1EE | JSA (income-based), closed 01/03/2026 to 31/08/2026 | No | Never | Same with RST-8365 |
| RST-8365 | Harvey Singh | 14/12/1973 | JC836508D | LE2 1TF | Income Support, active 01/03/2026 to 31/08/2026, £0 paid | Yes | 01/03/2026 to 11/10/2026 | Becomes No with RST-8365 (£0 paid) |
| RST-8365 | Imogen Castle | 19/03/1991 | JC836509A | NR1 3QY | JSA (income-based), suspended 01/03/2026 to 31/08/2026 | No | Never | Same with RST-8365 |
| RST-8365 | Jamal Whitaker | 05/08/1987 | JC836510B | SO14 7DW | Universal Credit, active from 16/06/2026<br>Income Support, closed 01/06/2026 to 15/06/2026 | Yes | 16/06/2026 onwards | Same with RST-8365 |
| RST-8365 | Keira Donnelly | 21/10/1992 | JC836511C | G2 3BZ | Universal Credit, closed 01/06/2026 to 15/06/2026<br>JSA (income-based), active from 16/06/2026 | Yes | 16/06/2026 onwards | Same with RST-8365 |
| RST-8365 | Liam Ashworth | 28/05/1980 | JC836512D | PL1 2AA | Carer's Allowance, active from 01/03/2026 | Yes | 01/03/2026 onwards | Becomes No with RST-8365 (benefit type not in the list) |
| Demo sandbox | Samantha Smith | 01/02/1981 | Any | AB12 5AJ | Universal Credit, in payment from 28/08/2024 | Yes | 28/08/2024 onwards | |
| Demo sandbox | Aly Turing | 01/03/2000 | Any | PH1 1BD | Universal Credit, in payment from 28/10/2022 | Yes | 28/10/2022 onwards | |
| Demo sandbox | Farah Parveen | 05/01/1949 | Any | G1 5LE | Pension Credit, active from 05/07/2025 | Yes | 05/07/2025 onwards | |
| Demo sandbox | Richard Edwards | 02/05/1943 | Any | Leave blank | Universal Credit, suspended from 18/10/2025 | No | Never | Stored postcode "L70 JQ" is not a valid format |
| Demo sandbox | Lisa Leeks | 26/04/1956 | Any | PO9 5TG | Pension Credit, status "decision_entitled" from 23/08/2024 | No | Never | |
| Demo sandbox | Andrew Connelly | 03/12/1992 | Any | G33 1GH | ESA (income-based), no claim status, live award from 01/01/2021 | Yes | 01/01/2021 onwards | Needs the live-award change; No without it |

Using them in the staff app:

- **Application date** is the date received (paper), the date fee paid (refund) or the day it was created (online).
- **First name, last name and DOB** must match exactly as shown (case does not matter).
- **NI number**: use the one shown, or leave it blank. Only its last four digits are sent, as the NI number fragment.
- **Postcode** is optional, but must match if entered.
- **RST-8365** examples were written for an application date of 13/07/2026.

Things to know:

- **RST-8365 is not implemented in the staff app yet.** Marsh, Nolan, Singh and Ashworth are Yes today because the staff app does not yet check take-home pay, the amount paid or the benefit type. They should become No once RST-8365 is in.
- **Andrew Connelly is Yes only when the staff app counts a live award** on a claim that has no status of its own.
- **Some NI numbers are constructed.** Ten of the general citizens have a stored `nino` that fails the staff app's format check or does not end in their `ninoFragment`. Theirs are built as `JC` + two digits + the fragment + `A`.

## Development

```bash
bundle install
cp .env.example .env
# Edit .env with your values
bundle exec rspec
```

### Console

```bash
bundle exec irb -r dotenv/load -r hwf-dwp-api
```

## License

MIT
