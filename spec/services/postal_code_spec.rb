# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostalCode do
  describe ".us_zip?" do
    it "accepts 5-digit ZIPs and ZIP+4" do
      expect(described_class.us_zip?("14546")).to be true
      expect(described_class.us_zip?("14546-1234")).to be true
      expect(described_class.us_zip?(" 14546 ")).to be true
    end

    it "rejects anything else" do
      expect(described_class.us_zip?("1454")).to be false
      expect(described_class.us_zip?("145467")).to be false
      expect(described_class.us_zip?("M15 5FS")).to be false
      expect(described_class.us_zip?("ZZMB 1RS")).to be false
      expect(described_class.us_zip?(nil)).to be false
      expect(described_class.us_zip?("")).to be false
    end
  end

  describe ".us_zip5" do
    it "extracts the 5-digit part" do
      expect(described_class.us_zip5("14546")).to eq("14546")
      expect(described_class.us_zip5("14546-1234")).to eq("14546")
      expect(described_class.us_zip5("M15 5FS")).to be_nil
    end
  end

  describe ".normalize" do
    it "normalizes US ZIPs" do
      expect(described_class.normalize(" 14546 ")).to eq("14546")
      expect(described_class.normalize("14546-1234")).to eq("14546-1234")
      expect(described_class.normalize("145461234")).to eq("14546-1234")
    end

    it "normalizes UK postcodes via UKPostcode" do
      expect(described_class.normalize("  m15  5dd  ")).to eq("M15 5DD")
      expect(described_class.normalize("ZZMB 1RS")).to eq("ZZMB 1RS")
    end

    it "passes unrecognised values through unchanged apart from whitespace" do
      expect(described_class.normalize("  not a code  ")).to eq("not a code")
      expect(described_class.normalize(nil)).to eq("")
    end
  end
end
