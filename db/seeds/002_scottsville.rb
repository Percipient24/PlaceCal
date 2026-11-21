# frozen_string_literal: true

require 'yaml'

# Seeds the US neighbourhood hierarchy for this deployment (Scottsville, NY):
#
#   United States (country, level 5)
#   └── New York (region, level 4)
#       └── Monroe County (county, level 3)
#           └── Scottsville (district, level 2, unit_code_value = ZIP "14546")
#
# The ZIPs come from config/geo/us_zips.yml, which is also what the local US ZIP
# lookup (UsZipLookup) uses, so a seeded ZIP geocodes and maps to its neighbourhood.
module SeedScottsville
  # YAML parses bare 5-digit keys as integers, so stringify them
  ZIPS = YAML.load_file(Rails.root.join('config/geo/us_zips.yml')).transform_keys(&:to_s).except('default').freeze

  COUNTRY_CODE = 'US000001'   # 9 chars, ISO-3166-style placeholder
  STATE_FIPS   = '36000000'   # New York state FIPS 36, padded to 9
  COUNTY_FIPS  = '36055000'   # Monroe County NY FIPS 36055, padded to 9

  def self.run # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return if ZIPS.empty?

    $stdout.puts 'Neighbourhoods - Scottsville, NY (USA)'

    country = Neighbourhood.find_or_create_by!(unit_code_value: COUNTRY_CODE) do |n|
      n.name = 'United States'
      n.name_abbr = 'US'
      n.unit = :country
      n.unit_code_key = 'ISO3166'
      n.unit_name = 'Country'
      n.release_date = Neighbourhood::LATEST_RELEASE_DATE
      n.level = 5
    end

    state = Neighbourhood.find_or_create_by!(unit_code_value: STATE_FIPS) do |n|
      n.name = 'New York'
      n.name_abbr = 'NY'
      n.unit = :region
      n.unit_code_key = 'FIPS'
      n.unit_name = 'State'
      n.release_date = Neighbourhood::LATEST_RELEASE_DATE
      n.parent = country
      n.level = 4
    end

    county = Neighbourhood.find_or_create_by!(unit_code_value: COUNTY_FIPS) do |n|
      n.name = 'Monroe County'
      n.name_abbr = 'Monroe'
      n.unit = :county
      n.unit_code_key = 'FIPS'
      n.unit_name = 'County'
      n.release_date = Neighbourhood::LATEST_RELEASE_DATE
      n.parent = state
      n.level = 3
    end
    $stdout.puts "  Country: #{country.name} > Region: #{state.name} > County: #{county.name}"

    ZIPS.each do |zip, data|
      place = Neighbourhood.find_or_create_by!(unit_code_value: zip) do |n|
        n.name = data['place']
        n.name_abbr = zip
        n.unit = :district
        n.unit_code_key = 'ZIP'
        n.unit_name = 'ZIP code area'
        n.release_date = Neighbourhood::LATEST_RELEASE_DATE
        n.parent = county
        n.level = 2
      end
      $stdout.puts "  District: #{place.name} (#{zip})"
    end
  end
end

SeedScottsville.run
