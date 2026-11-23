# frozen_string_literal: true

require 'yaml'

# Seeds the US neighbourhood hierarchy for this deployment (Scottsville, NY):
#
#   United States (country, level 5)
#   └── New York (region, level 4)
#       └── Monroe County (county, level 3)
#           └── Scottsville (district, level 2, unit_code_value = town code "SCOTTSVL")
#
# The TOWN is the primary geographic unit, not the ZIP: config/geo/us_zips.yml is
# keyed by town (each listing the ZIPs that resolve to it), one district-level
# Neighbourhood is seeded per town keyed by the town code, and UsZipLookup puts
# the town code in the geocoder result's codes — so any of a town's ZIPs geocodes
# to the town's district node. ZIPs need no Neighbourhood rows of their own; they
# are just address data (the Address's postcode).
module SeedScottsville
  TOWNS = YAML.load_file(Rails.root.join('config/geo/us_zips.yml')).fetch('towns').freeze

  COUNTRY_CODE = 'US000001'   # 9 chars, ISO-3166-style placeholder
  STATE_FIPS   = '36000000'   # New York state FIPS 36, padded to 9
  COUNTY_FIPS  = '36055000'   # Monroe County NY FIPS 36055, padded to 9

  def self.run # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return if TOWNS.empty?

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

    # One district per town; the town code is the unit_code_value the geocoder's
    # codes match against. ZIPs listed under the town need no rows of their own.
    TOWNS.each do |town_code, town|
      district = Neighbourhood.find_or_create_by!(unit_code_value: town_code) do |n|
        n.name = town['place']
        n.name_abbr = town['place']
        n.unit = :district
        n.unit_code_key = 'TOWN'
        n.unit_name = 'Town'
        n.release_date = Neighbourhood::LATEST_RELEASE_DATE
        n.parent = Neighbourhood.find_by(name: town['county'], unit: :county) || county
        n.level = 2
      end
      zips = (town['zips'] || {}).keys.join(', ')
      $stdout.puts "  District (town): #{district.name} (#{town_code}) — ZIPs: #{zips}"
    end
  end
end

SeedScottsville.run
