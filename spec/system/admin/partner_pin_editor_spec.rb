# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin partner pin editor", :slow, type: :system do
  include_context "admin login"

  let!(:new_york) do
    create(:neighbourhood, name: "New York", name_abbr: "NY", unit: :region, unit_code_key: "FIPS",
                           unit_code_value: "36000000", level: 4)
  end
  let!(:scottsville) do
    create(:neighbourhood, name: "Scottsville", unit: :district, unit_code_key: "ZIP",
                           unit_code_value: "14546", level: 2, parent: new_york)
  end
  let!(:partner) do
    create(:partner, address: create(:address, neighbourhood: scottsville, street_address: "61 Main Street",
                                               postcode: "14546", city: "Scottsville", country_code: "US",
                                               latitude: 43.019490119796, longitude: -77.754542372393))
  end

  def pin_editor_map
    find("[data-pin-editor-target='map']", wait: 15)
  end

  def lat_field = find_field("partner_address_attributes_latitude")
  def lng_field = find_field("partner_address_attributes_longitude")

  it "shows the OpenFreeMap embed with a pin at the address's saved coordinates" do
    visit admin_url("/partners/#{partner.id}/edit")
    go_to_place_tab

    map = pin_editor_map
    # Cold browser + CDN imports can take a while on the first example
    # L.map() puts .leaflet-container on the map div itself
    expect(page).to have_css("[data-pin-editor-target='map'].leaflet-container", wait: 60)
    expect(map).to have_css(".leaflet-marker-icon", wait: 60)
    expect(map).to have_css(".leaflet-control-zoom-in", wait: 60)
    expect(lat_field.value).to eq("43.019490119796")
    expect(lng_field.value).to eq("-77.754542372393")
  end

  it "moves the pin when the map is clicked and writes the new coordinates into the inputs" do
    visit admin_url("/partners/#{partner.id}/edit")
    go_to_place_tab

    map = pin_editor_map
    marker = map.find(".leaflet-marker-icon", wait: 60)
    position_before = marker[:style]

    # Click 80px right and 60px down from the map's top-left corner; Leaflet
    # turns the DOM click into a lat/lng and our controller moves the pin there
    page.execute_script(<<~JS, map.native)
      const el = arguments[0];
      const rect = el.getBoundingClientRect();
      el.dispatchEvent(new MouseEvent("click", {
        clientX: rect.left + 80, clientY: rect.top + 60, bubbles: true
      }));
    JS

    expect(lat_field.value).not_to eq("43.019490119796")
    expect(lng_field.value).not_to eq("-77.754542372393")
    expect(Float(lat_field.value)).to be_within(0.01).of(43.019490119796)
    expect(Float(lng_field.value)).to be_within(0.01).of(-77.754542372393)
    expect(map.find(".leaflet-marker-icon")[:style]).not_to eq(position_before)
  end

  it "re-geocodes and moves the pin when the ZIP changes" do
    visit admin_url("/partners/#{partner.id}/edit")
    go_to_place_tab

    map = pin_editor_map
    map.find(".leaflet-marker-icon", wait: 60)

    # Any unlisted 5-digit ZIP resolves to the hermetic test stub (43.0, -77.8)
    page.execute_script(<<~JS, find_field("partner_address_attributes_postcode").native)
      const el = arguments[0];
      el.value = "99999";
      el.dispatchEvent(new Event("change", { bubbles: true }));
    JS

    # The lookup is an async fetch, so wait for the inputs to update
    expect(page).to have_field("partner_address_attributes_latitude", with: "43.0000000", wait: 10)
    expect(page).to have_field("partner_address_attributes_longitude", with: "-77.8000000", wait: 10)
  end
end
