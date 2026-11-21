# frozen_string_literal: true

# Looks up a postal code — a US ZIP via UsZipLookup, anything else as a UK postcode
# with the configured geocoder (postcodes.io, or Normal Island data locally) —
# telling a code that doesn't exist apart from a lookup service that isn't responding.
module PostcodeLookup
  # Raised when the lookup service can't be reached or answers with an error
  class Unavailable < StandardError; end

  # The errors config/initializers/geocoder.rb tells Geocoder to raise rather than swallow
  OUTAGE_ERRORS = [
    SocketError, Errno::ECONNREFUSED, Geocoder::NetworkError, Timeout::Error, Geocoder::LookupTimeout,
    Geocoder::ServiceUnavailable, Geocoder::OverQueryLimitError, Geocoder::ResponseParseError
  ].freeze

  # @param postcode [String] a US ZIP or a UK postcode
  # @return [Hash, nil] the lookup result data (postcodes.io-shaped either way), or nil when it doesn't exist
  # @raise [Unavailable] when the lookup service isn't responding
  def self.call(postcode)
    return UsZipLookup.call(postcode) if PostalCode.us_zip?(postcode)

    Geocoder.search(postcode).first&.data
  rescue *OUTAGE_ERRORS => e
    raise Unavailable, "Postcode lookup failed: #{e.class}: #{e.message}"
  end

  # Like call, but treats an outage as no result, for callers with no way to report it
  # @return [Hash, nil]
  def self.call_or_nil(postcode)
    call(postcode)
  rescue Unavailable => e
    Rails.logger.warn(e.message)
    nil
  end
end
