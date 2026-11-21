# frozen_string_literal: true

module Admin
  # JSON endpoints backing the partner form's address fields.
  class AddressesController < ApplicationController
    # GET /addresses/lookup?postcode=14546&street=61+Main+Street&city=Scottsville
    #
    # Best-guess coordinates for the pin map editor in the partner form:
    # street-level for US addresses when the geocoder knows the street,
    # otherwise the postcode/ZIP centroid.
    def lookup
      authorize Address

      result = PostcodeLookup.call(params[:postcode].to_s, street: params[:street], city: params[:city])
      return render json: { error: t('admin.address.lookup_not_found') }, status: :not_found if result.nil?

      render json: {
        postcode: result['postcode'],
        latitude: result['latitude'],
        longitude: result['longitude']
      }
    rescue PostcodeLookup::Unavailable
      render json: { error: t('admin.address.lookup_unavailable') }, status: :service_unavailable
    end
  end
end
