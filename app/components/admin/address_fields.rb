# frozen_string_literal: true

class Components::Admin::AddressFields < Components::Admin::Base
  include ApplicationHelper
  include MapHelper
  include Phlex::Rails::Helpers::ImagePath

  prop :form, ActionView::Helpers::FormBuilder
  prop :partner, ::Partner

  def view_template
    # Store the nested form builder, then render Phlex content separately.
    # fields_for with capture/raw doesn't work in Phlex because the block
    # return value gets HTML-escaped. This approach avoids that issue.
    @form.fields_for(:address, address) do |address_form|
      @address_form = address_form
    end
    render_address_fields
  end

  private

  def render_address_fields
    div(
      class: 'nested-fields',
      data_controller: 'partner-address',
      data_partner_address_partner_id_value: @partner.id,
      data_partner_address_warn_of_delisting_value: warn_of_delisting_value
    ) do
      address_field_configs.each do |field_config|
        fieldset(class: 'fieldset') do
          label(for: @address_form.field_id(field_config[:field]), class: 'fieldset-legend') { attr_label(:address, field_config[:label_key]) }
          raw(@address_form.input_field(field_config[:field],
                                        class: 'input input-bordered w-full bg-base-100 address_field'))
        end
      end

      div(data_partner_address_target: 'addressInfoArea', class: 'mt-4') do
        if can_clear_address?
          link_to t('admin.address.clear_address'), '#',
                  class: 'btn btn-ghost btn-xs',
                  data: { action: 'click->partner-address#do_clear_address' }
        end
      end

      render_pin_fields
    end
  end

  # The map pin editor: an OpenFreeMap embed (same as the public pages) starting
  # at the geocoded best-guess for the address, with a draggable pin. The pin
  # position is written into the latitude/longitude inputs below, so a manual
  # tweak is submitted with the form and wins over re-geocoding on save.
  def render_pin_fields
    pin = pin_position
    args = {
      center: pin || default_map_center,
      pin:,
      zoom: pin ? 16 : 13,
      iconUrl: image_path('icons/map/map-marker.png'),
      shadowUrl: image_path('icons/map/map-shadow.png'),
      styleUrl: map_style_url,
      zoomIn: t('components.map.zoom_in'),
      zoomOut: t('components.map.zoom_out'),
      lookupUrl: lookup_admin_addresses_path
    }.to_json.html_safe

    div(class: 'mt-4', data: { controller: 'pin-editor', pin_editor_args_value: args }) do
      fieldset(class: 'fieldset') do
        legend(class: 'fieldset-legend') { t('admin.address.pin_legend') }
        p(class: 'text-sm opacity-70 mt-1') { t('admin.address.pin_hint') }
      end
      div(role: 'region', aria_label: t('admin.address.pin_map_label'),
          class: 'mt-2 h-80 border-5 border-rules rounded-card overflow-hidden z-0',
          data: { pin_editor_target: 'map' })
      div(class: 'grid grid-cols-2 gap-4 mt-2') do
        fieldset(class: 'fieldset') do
          label(for: @address_form.field_id(:latitude), class: 'fieldset-legend') { attr_label(:address, :latitude) }
          raw(@address_form.input_field(:latitude, type: 'number', step: 'any',
                                                   class: 'input input-bordered w-full bg-base-100',
                                                   data: { pin_editor_target: 'latitude' }))
        end
        fieldset(class: 'fieldset') do
          label(for: @address_form.field_id(:longitude), class: 'fieldset-legend') { attr_label(:address, :longitude) }
          raw(@address_form.input_field(:longitude, type: 'number', step: 'any',
                                                    class: 'input input-bordered w-full bg-base-100',
                                                    data: { pin_editor_target: 'longitude' }))
        end
      end
    end
  end

  # The address's saved coordinates, when both are present
  def pin_position
    return unless address.latitude.present? && address.longitude.present?

    [address.latitude, address.longitude]
  end

  # Where the editor map opens when the address has no coordinates yet: the
  # first covered town's centroid (the deployment's own geography, e.g.
  # Scottsville NY), falling back to the middle of the contiguous US.
  def default_map_center
    UsZipLookup.first_town_centroid || [39.8283, -98.5795]
  end

  def address
    @partner.address || ::Address.new
  end

  def warn_of_delisting_value
    @partner.warn_user_clear_address?(current_user) ? 'true' : 'false'
  end

  def can_clear_address?
    @partner.can_clear_address?(current_user)
  end

  def address_field_configs
    [
      { field: :street_address, label_key: :street_address },
      { field: :street_address2, label_key: :street_address_2 },
      { field: :street_address3, label_key: :street_address_3 },
      { field: :city, label_key: :city },
      { field: :postcode, label_key: :postcode }
    ]
  end
end
