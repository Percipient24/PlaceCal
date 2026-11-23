# frozen_string_literal: true

require 'net/http'
require 'json'
require 'yaml'

# Looks up a US ZIP code and returns a postcodes.io-shaped result hash, so the rest
# of the address pipeline (Address#geocode_with_ward,
# Neighbourhood.find_from_postcodesio_response) works unchanged for US addresses.
#
# config/geo/us_zips.yml is the local lookup table for the geography this
# deployment covers, keyed by TOWN — the primary geographic unit. The result's
# codes carry the town's code, so an address maps to its town's district-level
# Neighbourhood. The ZIP itself is only address data: it stays in the result's
# 'postcode' (and on the Address) and is never a Neighbourhood. ZIPs not listed
# under any town go to zippopotam.us (keyless, US-only) outside test, and to a
# stub in test.
module UsZipLookup
  RAW_GEO = YAML.load_file(Rails.root.join('config/geo/us_zips.yml')).freeze

  # town_code => town entry, e.g. { 'place' => 'Scottsville', 'county' => ..., 'zips' => { '14546' => {...} } }
  TOWNS = RAW_GEO.fetch('towns').freeze

  # Stub returned for any unlisted ZIP in the test environment
  DEFAULT = RAW_GEO['default']&.freeze

  # zip5 => lookup entry. A ZIP listed under several towns appears once, pointing
  # at the first town listed (an address can only link to one Neighbourhood).
  # YAML parses bare 5-digit keys as integers, so stringify them.
  ZIP_INDEX = TOWNS.each_with_object({}) do |(town_code, town), index|
    raw_zips = town['zips'] || {}
    zips = raw_zips.is_a?(Array) ? raw_zips.index_with(nil) : raw_zips.transform_keys(&:to_s)
    zips.each do |zip, coords|
      index[zip] ||= {
        'town_code' => town_code,
        'place' => town['place'],
        'county' => town['county'],
        'latitude' => coords&.dig('latitude') || town['latitude'],
        'longitude' => coords&.dig('longitude') || town['longitude']
      }
    end
  end.freeze

  # @param zip [String] a US ZIP (5 digits) or ZIP+4
  # @return [Hash, nil] postcodes.io-shaped result, or nil when the ZIP doesn't exist
  # @raise [PostcodeLookup::Unavailable] when the lookup service isn't responding
  def self.call(zip)
    zip5 = PostalCode.us_zip5(zip)
    return nil if zip5.blank?

    entry = ZIP_INDEX[zip5]
    return shape(zip5, entry) if entry
    return shape(zip5, DEFAULT) if Rails.env.test? && DEFAULT

    lookup_remote(zip5)
  end

  # Street-level lookup for a full US address: asks the US Census geocoder for the
  # street address inside the ZIP and falls back to the ZIP centroid (call) when
  # there's no match or the geocoder can't be reached. Test env stays hermetic and
  # uses the ZIP-level stub.
  # @param zip [String] a US ZIP (5 digits) or ZIP+4
  # @param street [String, nil] first street line, e.g. "61 Main Street"
  # @param city [String, nil] city/town, e.g. "Scottsville"
  # @return [Hash, nil] postcodes.io-shaped result, or nil when the ZIP doesn't exist
  # @raise [PostcodeLookup::Unavailable] when the ZIP-level fallback can't be reached
  def self.call_address(zip, street: nil, city: nil)
    zip5 = PostalCode.us_zip5(zip)
    return nil if zip5.blank?

    return call(zip5) if Rails.env.test?

    street_level(zip5, street, city) || call(zip5)
  end

  # US Census Bureau geocoder (keyless, US-only): precise coordinates for a street
  # address. Returns nil when there's no match or on any network/parse error, so
  # callers can fall back to the ZIP centroid.
  # @return [Hash, nil]
  def self.street_level(zip5, street, city)
    return nil if street.blank?

    params = { street:, zip: zip5, benchmark: 'Public_AR_Current', format: 'json' }
    params[:city] = city if city.present?
    uri = URI('https://geocoding.geo.census.gov/geocoder/locations/address')
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.get(uri.request_uri, 'Accept' => 'application/json')
    end
    return nil unless response.is_a?(Net::HTTPSuccess)

    match = JSON.parse(response.body).dig('result', 'addressMatches')&.first
    return nil if match.blank?

    coords = match['coordinates']
    shape(zip5, {
            'place' => match.dig('addressComponents', 'city')&.titleize || city,
            'county' => nil, # Census address geocoder doesn't return county
            'town_code' => ZIP_INDEX.dig(zip5, 'town_code'),
            'latitude' => coords['y'],
            'longitude' => coords['x']
          })
  rescue StandardError
    nil
  end

  # @return [Hash, nil] shaped result from zippopotam.us, or nil for a 404
  def self.lookup_remote(zip5)
    uri = URI("https://api.zippopotam.us/us/#{zip5}")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.get(uri.request_uri, 'Accept' => 'application/json')
    end
    return nil if response.code == '404'
    raise PostcodeLookup::Unavailable, "ZIP lookup failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    place = JSON.parse(response.body).fetch('places', []).first
    return nil if place.blank?

    shape(zip5, {
            'place' => place['place name'],
            'county' => nil, # zippopotam.us doesn't return county
            'town_code' => town_code_for_place(place['place name']),
            'latitude' => place['latitude'],
            'longitude' => place['longitude']
          })
  rescue PostcodeLookup::Unavailable
    raise
  rescue StandardError => e
    raise PostcodeLookup::Unavailable, "ZIP lookup failed: #{e.class}: #{e.message}"
  end

  # Map a place name from a remote lookup onto a locally covered town_code, so a
  # ZIP that isn't listed in us_zips.yml still resolves to its town's Neighbourhood
  # when the town is one this deployment covers.
  # @param place [String, nil] place name, e.g. "Scottsville"
  # @return [String, nil] the town code, or nil when no covered town matches
  def self.town_code_for_place(place)
    return nil if place.blank?

    wanted = place.to_s.downcase
    TOWNS.each do |town_code, town|
      return town_code if town['place'].to_s.downcase == wanted
    end
    nil
  end

  # @return [Array(Float, Float), nil] the first covered town's centroid, for the
  #   admin pin map's default center
  def self.first_town_centroid
    _town_code, town = TOWNS.find { |_code, t| t['latitude'] }
    [town['latitude'].to_f, town['longitude'].to_f] if town
  end

  # The keys mirror what postcodes.io returns for a UK postcode: the address pipeline
  # reads admin_district/admin_county/country for place names, latitude/longitude for
  # the map, and codes.admin_ward/admin_district to match a Neighbourhood's
  # unit_code_value. For US addresses the codes carry the town code, so the address
  # lands on the town's district-level Neighbourhood; the ZIP stays in 'postcode'.
  # @return [Hash]
  def self.shape(zip5, data)
    town_code = data['town_code'].presence || zip5
    {
      'postcode' => zip5,
      'latitude' => data['latitude'].to_f,
      'longitude' => data['longitude'].to_f,
      'country' => 'United States',
      'admin_district' => data['place'],
      'admin_county' => data['county'],
      'admin_ward' => data['place'],
      'codes' => { 'admin_ward' => town_code, 'admin_district' => town_code }
    }
  end
end
