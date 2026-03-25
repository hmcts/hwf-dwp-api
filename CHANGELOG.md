# Changelog

## [0.1.1] - 2026-03-25

### Changed

- Renamed gem from `hwf_dwp_api` to `hwf-dwp-api`

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
