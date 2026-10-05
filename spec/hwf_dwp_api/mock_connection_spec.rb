# frozen_string_literal: true

# DWP_API_CONNECTION=mock_dwp answers from the test citizens in
# lib/hwf-dwp-api/mock/citizens instead of calling DWP.
RSpec.describe HwfDwpApi, 'mock connection' do
  subject(:connection) { described_class.new }

  # sarah_williams.yml - ESA claim in payment since 2022
  let(:sarah) { { last_name: 'WILLIAMS', date_of_birth: '1978-12-03' } }
  let(:sarah_guid) { 'mock-dwp-citizen_004' }
  let(:window) { { effective_from: '2026-08-24', effective_to: '2026-09-30' } }
  let(:dwp_env_keys) { described_class::ENV_MAPPING.values + ['DWP_API_CONNECTION'] }

  def error_from
    yield
    nil
  rescue HwfDwpApiError => e
    e
  end

  around do |example|
    original_env = ENV.to_h.slice(*dwp_env_keys)
    dwp_env_keys.each { |key| ENV.delete(key) }
    ENV['DWP_API_CONNECTION'] = 'mock_dwp'
    example.run
  ensure
    dwp_env_keys.each { |key| ENV.delete(key) }
    ENV.update(original_env)
  end

  before { allow($stdout).to receive(:puts) }

  describe '.new' do
    it 'connects without any DWP credentials' do
      expect(connection).to be_a(HwfDwpApi::Connection)
    end

    it 'provides a token the caller can cache' do
      expect(connection.authentication.access_token).to eq 'mock-dwp-token'
      expect(connection.authentication.expires_in).to be > Time.now
    end

    it 'warns that DWP is not being called' do
      connection
      expect($stdout).to have_received(:puts).with(/mock_dwp.*DWP is not called/)
    end

    it 'does not call DWP' do
      connection.match_citizen(sarah)
      connection.get_claims(sarah_guid, window)
      expect(WebMock).not_to have_requested(:any, /.*/)
    end
  end

  describe '#match_citizen' do
    it 'matches on last name and date of birth, ignoring case' do
      response = connection.match_citizen(sarah)

      expect(response.dig('data', 'id')).to eq sarah_guid
      expect(response.dig('data', 'type')).to eq 'MatchResult'
      expect(response.dig('data', 'attributes', 'matchingScenario')).to eq 'scenario_1'
    end

    it 'stores the guid for the following calls' do
      connection.match_citizen(sarah)
      expect(connection.citizen_guid).to eq sarah_guid
    end

    it 'matches when the optional details agree' do
      response = connection.match_citizen(sarah.merge(first_name: 'sarah', nino_fragment: '9012', postcode: 'ls11ba'))

      expect(response.dig('data', 'id')).to eq sarah_guid
    end

    it 'does not match when the NI number fragment is different' do
      error = error_from { connection.match_citizen(sarah.merge(nino_fragment: '0000')) }

      expect(error.error_type).to eq :not_found
      expect(JSON.parse(error.message).dig('errors', 0, 'status')).to eq '404'
    end

    it 'does not match an unknown citizen' do
      error = error_from { connection.match_citizen(last_name: 'Nobody', date_of_birth: '1970-01-01') }

      expect(error.error_type).to eq :not_found
    end

    # jane_smith.yml and ambiguous_smith.yml share a last name and date of birth
    it 'asks for more details when two citizens match' do
      error = error_from { connection.match_citizen(last_name: 'Smith', date_of_birth: '1985-06-15') }

      expect(error.error_type).to eq :unprocessable
      expect(JSON.parse(error.message).dig('errors', 0, 'detail')).to eq 'Further details required'
    end

    it 'tells two citizens apart by the NI number fragment' do
      response = connection.match_citizen(last_name: 'Smith', date_of_birth: '1985-06-15', nino_fragment: '4455')

      expect(response.dig('data', 'id')).to eq 'mock-dwp-citizen_008'
    end
  end

  describe '#get_claims' do
    it 'returns the claims of the matched citizen' do
      claim = connection.get_claims(sarah_guid, window)['data'].first

      expect(claim['type']).to eq 'Claim'
      expect(claim.dig('attributes', 'guid')).to eq sarah_guid
      expect(claim.dig('attributes', 'benefitType')).to eq 'employment_support_allowance_income_based'
      expect(claim.dig('attributes', 'status')).to eq 'in_payment'
    end

    it 'returns the awards of a claim' do
      claim = connection.get_claims(sarah_guid, window)['data'].first

      expect(claim.dig('attributes', 'startDate')).to eq '2022-07-15'
      expect(claim.dig('attributes', 'awards', 0, 'status')).to eq 'live'
    end

    it 'uses the guid stored by match_citizen' do
      connection.match_citizen(sarah)

      expect(connection.get_claims['data'].size).to eq 1
    end

    # claim_ended_before_window.yml - claim ended 2026-08-21
    it 'leaves out claims that ended before the window' do
      error = error_from { connection.get_claims('mock-dwp-citizen_013', window) }

      expect(error.error_type).to eq :not_found
      expect(JSON.parse(error.message).dig('errors', 0, 'detail')).to eq 'No claims found for the supplied criteria'
    end

    it 'returns a claim that ended inside the window' do
      response = connection.get_claims('mock-dwp-citizen_013', effective_from: '2026-08-01', effective_to: '2026-08-31')

      expect(response['data'].first.dig('attributes', 'endDate')).to eq '2026-08-21'
    end

    it 'returns only open claims when there is no window' do
      error = error_from { connection.get_claims('mock-dwp-citizen_013') }

      expect(error.error_type).to eq :not_found
    end

    it 'filters by benefit type' do
      error = error_from { connection.get_claims(sarah_guid, benefit_type: 'universal_credit') }

      expect(error.error_type).to eq :not_found
    end

    # mary_jones.yml - no claims
    it 'returns not found for a citizen without claims' do
      error = error_from { connection.get_claims('mock-dwp-citizen_006', window) }

      expect(error.error_type).to eq :not_found
    end

    # peter_wilson.yml - a claim DWP returns with no attributes
    it 'returns a claim with empty attributes' do
      response = connection.get_claims('mock-dwp-citizen_009', window)

      expect(response['data'].first['attributes']).to eq({})
    end

    # rate_limited_user.yml - rate limiting is not mocked
    it 'returns the claims of the rate limited test citizen' do
      response = connection.get_claims('mock-dwp-citizen_010', window)

      expect(response['data']).not_to be_empty
    end

    it 'returns not found for an unknown guid' do
      error = error_from { connection.get_claims('mock-dwp-unknown', window) }

      expect(error.error_type).to eq :not_found
      expect(JSON.parse(error.message).dig('errors', 0, 'detail')).to eq 'No citizen found for the supplied GUID'
    end
  end

  describe '#get_citizen' do
    it 'returns the details of the matched citizen' do
      response = connection.get_citizen(sarah_guid)

      expect(response.dig('data', 'type')).to eq 'Citizen'
      expect(response.dig('data', 'attributes', 'guid')).to eq sarah_guid
      expect(response.dig('data', 'attributes', 'name', 'lastName')).to eq 'Williams'
    end

    it 'returns not found for an unknown guid' do
      error = error_from { connection.get_citizen('mock-dwp-unknown') }

      expect(error.error_type).to eq :not_found
    end
  end

  describe 'test citizens' do
    let(:citizens) { HwfDwpApi::Mock::TestCitizens.all }

    it 'loads every file' do
      expect(citizens.size).to eq Dir.glob(File.join(HwfDwpApi::Mock::TestCitizens::DIRECTORY, '*.yml')).size
    end

    it 'gives every citizen its own id' do
      ids = citizens.map { |citizen| citizen['internal_id'] }

      expect(ids.uniq.size).to eq citizens.size
    end

    it 'gives every citizen a last name and date of birth to match on' do
      incomplete = citizens.reject do |citizen|
        citizen.dig('match_attributes', 'lastName') && citizen.dig('match_attributes', 'dateOfBirth')
      end

      expect(incomplete).to be_empty
    end
  end
end
