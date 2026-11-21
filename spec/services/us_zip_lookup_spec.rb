# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsZipLookup do
  describe ".call" do
    it "resolves a locally listed ZIP (14546 Scottsville) with no network call" do
      result = described_class.call("14546")

      expect(result["postcode"]).to eq("14546")
      expect(result["latitude"]).to be_within(0.001).of(43.0333)
      expect(result["longitude"]).to be_within(0.001).of(-77.7833)
      expect(result["admin_district"]).to eq("Scottsville")
      expect(result["admin_county"]).to eq("Monroe County")
      expect(result["country"]).to eq("United States")
      # codes drive Neighbourhood.find_from_postcodesio_response: the ZIP is the ward/district code
      expect(result["codes"]).to eq("admin_ward" => "14546", "admin_district" => "14546")
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
