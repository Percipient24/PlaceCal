# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsZipLookup do
  describe ".call" do
    it "resolves a locally listed ZIP (14546 Scottsville) with no network call" do
      result = described_class.call("14546")

      expect(result["postcode"]).to eq("14546")
      expect(result["latitude"]).to be_within(0.001).of(43.0246)
      expect(result["longitude"]).to be_within(0.001).of(-77.7743)
      expect(result["admin_district"]).to eq("Scottsville")
      expect(result["admin_county"]).to eq("Monroe County")
      expect(result["country"]).to eq("United States")
      # codes drive Neighbourhood.find_from_postcodesio_response: they carry the
      # TOWN code, so the address maps to the town's district-level Neighbourhood
      # (the ZIP itself is not a Neighbourhood, just address data)
      expect(result["codes"]).to eq("admin_ward" => "SCOTTSVL", "admin_district" => "SCOTTSVL")
    end

    it "accepts ZIP+4 and resolves on the 5-digit part" do
      expect(described_class.call("14546-1234")["postcode"]).to eq("14546")
    end

    it "returns the test stub for an unlisted ZIP in the test environment" do
      result = described_class.call("99999")

      expect(result["postcode"]).to eq("99999")
      expect(result["admin_district"]).to eq("Testville")
    end

    it "returns nil for a non-ZIP" do
      expect(described_class.call("M15 5FS")).to be_nil
    end
  end

  describe ".call_address" do
    it "returns the ZIP-level local result in the test environment (hermetic, no network)" do
      result = described_class.call_address("14546", street: "61 Main Street", city: "Scottsville")

      expect(result["postcode"]).to eq("14546")
      expect(result["latitude"]).to be_within(0.001).of(43.0246)
      expect(result["codes"]).to eq("admin_ward" => "SCOTTSVL", "admin_district" => "SCOTTSVL")
    end

    it "returns nil for a non-ZIP" do
      expect(described_class.call_address("M15 5FS", street: "1 High St")).to be_nil
    end
  end

  describe ".street_level (US Census geocoder)" do
    let(:census_url) { "https://geocoding.geo.census.gov/geocoder/locations/address" }

    it "returns precise coordinates for a matched street address" do
      stub_request(:get, census_url).with(query: hash_including(street: "61 Main Street", zip: "14546", city: "Scottsville"))
                                    .to_return(status: 200, body: {
                                      result: {
                                        addressMatches: [{
                                          coordinates: { x: -77.754542372393, y: 43.019490119796 },
                                          addressComponents: { city: "SCOTTSVILLE", zip: "14546", state: "NY" },
                                          matchedAddress: "61 MAIN ST, SCOTTSVILLE, NY, 14546"
                                        }]
                                      }
                                    }.to_json)

      result = described_class.street_level("14546", "61 Main Street", "Scottsville")

      expect(result["latitude"]).to be_within(0.000001).of(43.019490119796)
      expect(result["longitude"]).to be_within(0.000001).of(-77.754542372393)
      expect(result["admin_district"]).to eq("Scottsville")
      expect(result["codes"]["admin_ward"]).to eq("SCOTTSVL")
    end

    it "returns nil when the Census geocoder has no match, so callers fall back to the ZIP centroid" do
      stub_request(:get, census_url).with(query: hash_including(zip: "14546"))
                                    .to_return(status: 200, body: { result: { addressMatches: [] } }.to_json)

      expect(described_class.street_level("14546", "999 Nowhere Rd", "Scottsville")).to be_nil
    end

    it "returns nil on network failure so callers fall back to the ZIP centroid" do
      stub_request(:get, census_url).to_timeout

      expect(described_class.street_level("14546", "61 Main Street", "Scottsville")).to be_nil
    end

    it "returns nil without a street line" do
      expect(described_class.street_level("14546", nil, "Scottsville")).to be_nil
      expect(described_class.street_level("14546", "", nil)).to be_nil
    end
  end

  describe ".lookup_remote" do
    it "shapes a zippopotam.us response" do
      stub_request(:get, "https://api.zippopotam.us/us/10001").to_return(
        status: 200,
        body: {
          post_code: "10001",
          country: "United States",
          places: [{ "place name" => "New York", "state abbreviation" => "NY", "state" => "New York",
                     "latitude" => "40.7128", "longitude" => "-74.0060" }]
        }.to_json
      )

      result = described_class.lookup_remote("10001")

      expect(result["postcode"]).to eq("10001")
      expect(result["admin_district"]).to eq("New York")
      expect(result["latitude"]).to eq(40.7128)
      expect(result["longitude"]).to eq(-74.0060)
      expect(result["codes"]["admin_ward"]).to eq("10001")
    end

    it "maps a remote place name onto a covered town's code when the ZIP isn't listed locally" do
      stub_request(:get, "https://api.zippopotam.us/us/14599").to_return(
        status: 200,
        body: {
          post_code: "14599",
          places: [{ "place name" => "Scottsville", "latitude" => "43.02", "longitude" => "-77.77" }]
        }.to_json
      )

      result = described_class.lookup_remote("14599")

      expect(result["codes"]).to eq("admin_ward" => "SCOTTSVL", "admin_district" => "SCOTTSVL")
    end

    it "returns nil when the remote service says the ZIP does not exist" do
      stub_request(:get, "https://api.zippopotam.us/us/00000").to_return(status: 404)

      expect(described_class.lookup_remote("00000")).to be_nil
    end

    it "raises PostcodeLookup::Unavailable when the service cannot be reached" do
      stub_request(:get, "https://api.zippopotam.us/us/10001").to_timeout

      expect { described_class.lookup_remote("10001") }.to raise_error(PostcodeLookup::Unavailable, /ZIP lookup failed/)
    end
  end
end
