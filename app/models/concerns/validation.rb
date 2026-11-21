# frozen_string_literal: true

module Validation
  # Simple URL format check — validates structure, not reachability.
  URL_REGEX = %r{\Ahttps?://[^\s]+\z}i.freeze

  # Calendar sources also accept webcal:// scheme
  CALENDAR_URL_REGEX = %r{\A(https?|webcal)://[^\s]+\z}i.freeze

  UK_NUMBER_PATTERN = '(?:(?:\(?(?:0(?:0|11)\)?[\s-]?\(?|\+)44\)?[\s-]?(?:\(?0\)?[\s-]?)?)|(?:\(?0))(?:(?:\d{5}\)?[\s-]?\d{4,5})|(?:\d{4}\)?[\s-]?(?:\d{5}|\d{3}[\s-]?\d{3}))|(?:\d{3}\)?[\s-]?\d{3}[\s-]?\d{3,4})|(?:\d{2}\)?[\s-]?\d{4}[\s-]?\d{4}))(?:[\s-]?(?:x|ext\.?|\#)\d{3,4})?'.freeze # rubocop:disable Layout/LineLength
  # US/Canada (NANP): optional +1 country code, 3-3-4 digits with optional separators/parens, optional extension
  US_NUMBER_PATTERN = '(?:\+?1[\s.-]?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}(?:[\s.-]?(?:x|ext\.?|\#)\d{1,5})?'.freeze

  UK_NUMBER_REGEX = /\A#{UK_NUMBER_PATTERN}\z/.freeze
  US_NUMBER_REGEX = /\A#{US_NUMBER_PATTERN}\z/i.freeze
  # Phone numbers we accept: UK or US/Canada
  PHONE_REGEX = /\A(?:#{UK_NUMBER_PATTERN}|#{US_NUMBER_PATTERN})\z/i.freeze

  EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i.freeze
end
