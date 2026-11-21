# frozen_string_literal: true

require "rails_helper"

RSpec.describe CalendarImporter::Events::Base do
  describe ".postcode_in" do
    it "finds a US ZIP in free-text location" do
      expect(described_class.postcode_in("Scottsville Community Center, 123 Main St, Scottsville, NY 14546"))
        .to eq("14546")
      expect(described_class.postcode_in("Village Hall, NY 14546-1234")).to eq("14546-1234")
    end

    it "still finds UK postcodes" do
      expect(described_class.postcode_in("Moss Side, Hulme, Manchester M15 5FS")).to eq("M15 5FS")
      expect(described_class.postcode_in("ZZMB 1RS")).to eq("ZZMB 1RS")
    end

    it "returns an empty string when there is no postal code" do
      expect(described_class.postcode_in("Scottsville Community Center, Main St")).to eq("")
      expect(described_class.postcode_in("")).to eq("")
    end
  end
end
