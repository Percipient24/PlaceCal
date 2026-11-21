# frozen_string_literal: true

# Recognises and normalizes the postal code formats PlaceCal supports:
# US ZIP codes (this deployment: Scottsville, NY) and UK postcodes
# (via the UKPostcode gem, including Normal Island's ZZ codes in dev/test).
module PostalCode
  # 5-digit ZIP or ZIP+4, e.g. "14546" or "14546-1234"
  US_ZIP = /\A\d{5}(-\d{4})?\z/.freeze
  # Captures the 5-digit part of a ZIP or ZIP+4
  US_ZIP5 = /\A(\d{5})(?:-\d{4})?\z/.freeze

  module_function

  # @param value [String, nil]
  # @return [Boolean] true if the value is a US ZIP code (5 digits or ZIP+4)
  def us_zip?(value)
    value.to_s.strip.match?(US_ZIP)
  end

  # @param value [String, nil] a US ZIP or ZIP+4
  # @return [String, nil] the 5-digit ZIP part, or nil if not a ZIP
  def us_zip5(value)
    value.to_s.strip[US_ZIP5, 1]
  end

  # Normalize a postal code for storage: US ZIPs become "12345" or "12345-6789",
  # anything else goes through UKPostcode (which normalizes valid UK postcodes and
  # passes anything else through unchanged).
  # @param value [String, nil]
  # @return [String]
  def normalize(value)
    str = value.to_s.strip
    if (zip = str.match(/\A(\d{5})-?(\d{4})?\z/))
      return zip[2] ? "#{zip[1]}-#{zip[2]}" : zip[1]
    end

    UKPostcode.parse(str).to_s
  end
end
