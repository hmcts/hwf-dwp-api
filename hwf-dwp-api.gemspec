# frozen_string_literal: true

require_relative 'lib/hwf-dwp-api/version'

Gem::Specification.new do |spec|
  spec.name          = 'hwf-dwp-api'
  spec.version       = HwfDwpApi::VERSION
  spec.authors       = ['Petr Zaparka']
  spec.email         = ['petr@zaparka.cz']

  spec.summary       = 'Link between HwF and DWP Citizen API.'
  spec.description   = 'Basic logic to communicate and parse data to/from DWP Citizen API for benefit checks.'
  spec.homepage      = 'https://github.com/hmcts/hwf_dwp_api'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 4.0.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/hmcts/hwf_dwp_api'
  spec.metadata['changelog_uri'] = 'https://github.com/hmcts/hwf_dwp_api/blob/main/CHANGELOG.md'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'httparty', '~> 0.24.0'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
