# Changelog

## [0.3.4] - 2026-05-21

### Added

- Surface additional HTTP error responses from the DWP Citizen API as distinct error types across the `match_citizen`, `claims`, and `citizen` endpoints: `403 Forbidden` (`:forbidden`), `405 Method Not Allowed` (`:method_not_allowed`), `412 Precondition Failed` (`:precondition_failed`), and `503 Service Unavailable` (`:service_unavailable`). Previously these fell through to the generic `:standard_error` type. The raw JSON response body is preserved as the error message.

## [0.3.3] - 2026-04-22

### Added

- Surface HTTP 429 responses from the DWP Citizen API as a distinct `:rate_limited` error type across all four endpoints (`match_citizen`, `claims`, `citizen`, `token`), so downstream consumers can distinguish rate-limit errors from generic failures. The raw JSON response body is preserved as the error message.

## [0.3.2] - 2026-04-21

### Fixed

- Blank, whitespace-only, and nil optional parameters (firstName, ninoFragment, postcode) are now excluded from the match citizen API request body, preventing DWP from treating empty strings as actual values

## [0.3.1] - 2026-04-21

### Fixed

- Fixed CA bundle handling: replaced invalid `ssl_ca_cert` HTTParty option with `cert_store` (OpenSSL::X509::Store), resolving certificate verification errors when using the gem
- Added newline separator between client cert and key in PEM concatenation
- Removed sensitive data (client_id) from authentication log output
- Added `inspect` methods to `Connection` and `Authentication` to prevent certificate/secret leakage in console output

## [0.3.0] - 2026-04-20

### Fixed

- Fixed OAuth token endpoint URL from `/citizens-information/` to `/citizen-information/` (singular)
- Token auto-renewal now works correctly when token expires mid-session. `Connection#access_token` calls `Authentication#token` which checks expiry, instead of bypassing the check via the `access_token` attr_reader.

### Added

- Certificate values can now be passed as PEM text (from env vars/key vaults) or file paths. Detected automatically by the presence of `BEGIN` marker.
- Authentication logging to stdout for mTLS configuration, token requests, renewals, and cached token usage
- HTTParty debug output enabled via `DWP_DEBUG` environment variable

### Changed

- Enabled `rubocop-rspec` plugin in RuboCop configuration
- Disabled `SuggestExtensions` in RuboCop configuration
- Updated `mcp` gem from 0.8.0 to 0.13.0 (CVE-2026-33946 fix)

## [0.2.0] - 2026-03-26

### Changed

- Renamed gem from `hwf_dwp_api` to `hwf-dwp-api`
- Renamed all file paths from underscores to hyphens (`lib/hwf-dwp-api/`)
- Require path is now `require 'hwf-dwp-api'`
- Refactored `HwfDwpApi.new` from `class << self` to `def self.new` for better RSpec verifiability

## [0.1.0] - 2026-03-25

### Added

- OAuth2 authentication with automatic token management and renewal
- mTLS support for certificate-based communication with the DWP API
- Environment variable configuration for all connection attributes (`DWP_API_URL`, `DWP_CLIENT_ID`, `DWP_CLIENT_SECRET`, `DWP_CLIENT_CERT`, `DWP_CLIENT_KEY`, `DWP_CONTEXT`, `DWP_POLICY_ID`, `DWP_CA_BUNDLE`)
- Dotenv support for loading configuration from `.env` files
- Citizen matching (`match_citizen`) with required (last name, date of birth) and optional (first name, NINO fragment, postcode) parameters
- Citizen details retrieval (`get_citizen`) for fetching full citizen data by ID
- Claims lookup (`get_claims`) with optional filters by benefit type and date range
- Automatic citizen ID rotation tracking across requests
- Structured error handling with `HwfDwpApiError` and `HwfDwpApiTokenError`, JSON-formatted error messages, and typed `error_type` attributes
- Connection attribute validation with descriptive error messages
- Constructor args override ENV values for all configuration attributes
