# frozen_string_literal: true

require 'date'
require 'yaml'

module HwfDwpApi
  module Mock
    # The test citizens, one YAML file each in mock/citizens
    module TestCitizens
      DIRECTORY = File.expand_path('citizens', __dir__)
      GUID_PREFIX = 'mock-dwp-'

      module_function

      def all
        @all ||= Dir.glob(File.join(DIRECTORY, '*.yml')).map do |file|
          YAML.safe_load_file(file, permitted_classes: [Date]).fetch('citizen')
        end
      end

      # The same citizen always gets the same guid, so nothing has to be remembered between calls
      def guid_for(citizen)
        "#{GUID_PREFIX}#{citizen['internal_id']}"
      end

      def find_by_guid(guid)
        all.find { |citizen| guid_for(citizen) == guid }
      end
    end
  end
end
