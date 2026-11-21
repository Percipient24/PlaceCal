# frozen_string_literal: true

class PostcodeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    return if PostalCode.us_zip?(value)

    ukpc = UKPostcode.parse(value)

    record.errors.add(attribute, 'not recognised as a postcode or ZIP code') unless ukpc.full_valid?
  end
end
