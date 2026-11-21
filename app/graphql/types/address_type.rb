# frozen_string_literal: true

module Types
  class AddressType < Types::BaseObject
    description 'An address representing a physical location'

    # field :id, ID, null: false
    field :street_address, String,
          method: :full_street_address,
          description: 'The first few lines of the address like: 123 Main St, Scottsville, NY 14546'

    field :address_locality, String,
          description: 'The neighbourhood (locality) this address is in, e.g. "Scottsville"'

    field :address_region, String,
          description: 'The region/state this address is in, e.g. "New York"'

    field :address_country, String,
          method: :country_code,
          description: 'The ISO 3166-1 alpha-2 country code of the address, e.g. "US"'

    field :postal_code, String,
          method: :postcode,
          description: 'A US ZIP code (e.g. "14546") or UK postcode (e.g. "M15 5FS")'

    field :neighbourhood, NeighbourhoodType,
          description: 'The neighbourhood of this address (see neighbourhood type)'

    field :geo, GeoCoordinatesType,
          null: true,
          description: 'The geo coordinates of the place.'

    # TODO: figure out parent and children accessors
    # field :containedInPlace
    # field :containedPlace

    def geo
      object
    end

    def address_locality
      object.neighbourhood&.name
    end

    def address_region
      object.neighbourhood&.region&.name
    end
  end
end
