# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlaceCal::HexColour do
  describe ".valid? (FORMAT)" do
    it "accepts #rgb, #rrggbb and #rrggbbaa in any case" do
      expect(described_class.valid?("#abc")).to be(true)
      expect(described_class.valid?("#A1B2C3")).to be(true)
      expect(described_class.valid?("#aabbccdd")).to be(true)
    end

    it "rejects everything else" do
      expect(described_class.valid?("red")).to be(false) # colour keyword
      expect(described_class.valid?("f19089")).to be(false) # missing #
      expect(described_class.valid?("#12345")).to be(false) # 5 digits
      expect(described_class.valid?("#1234567")).to be(false) # 7 digits
      expect(described_class.valid?("#gggggg")).to be(false)
      expect(described_class.valid?("")).to be(false)
      expect(described_class.valid?(nil)).to be(false)
    end
  end

  describe ".parse" do
    it "returns nil for a blank value" do
      expect(described_class.parse(nil)).to be_nil
      expect(described_class.parse("")).to be_nil
      expect(described_class.parse("  ")).to be_nil
    end

    it "parses a valid hex" do
      expect(described_class.parse("#f19089").to_s).to eq("#f19089")
    end

    it "raises ArgumentError for anything else invalid" do
      expect { described_class.parse("red") }.to raise_error(ArgumentError, /not a hex colour/)
    end
  end

  describe "#initialize and #to_s" do
    it "normalises to a downcased 6-digit hex" do
      expect(described_class.new("#ABC").to_s).to eq("#aabbcc")
      expect(described_class.new("#F19089").to_s).to eq("#f19089")
    end

    it "drops the alpha channel of an 8-digit hex" do
      expect(described_class.new("#f19089ff").to_s).to eq("#f19089")
    end

    it "raises ArgumentError on an invalid value" do
      expect { described_class.new("#12345") }.to raise_error(ArgumentError)
    end
  end

  describe "#to_rgb" do
    it "parses the channels" do
      expect(described_class.new("#f19089").to_rgb).to eq([241, 144, 137])
      expect(described_class.new("#000").to_rgb).to eq([0, 0, 0])
      expect(described_class.new("#fff").to_rgb).to eq([255, 255, 255])
    end
  end

  describe "#to_hsl and .from_hsl" do
    it "computes the built-in pink base's channels" do
      hue, saturation, lightness = described_class.new("#f19089").to_hsl
      expect(hue).to be_within(0.01).of(4.04)
      expect(saturation).to be_within(0.001).of(0.788)
      expect(lightness).to be_within(0.001).of(0.741)
    end

    it "treats grey as zero saturation" do
      expect(described_class.new("#808080").to_hsl).to eq([0.0, 0.0, 128 / 255.0])
    end

    it "round-trips through from_hsl" do
      %w[#f19089 #afcf5a #74d4ec #fe9263 #123456 #808080].each do |hex|
        hue, saturation, lightness = described_class.new(hex).to_hsl
        expect(described_class.from_hsl(hue, saturation, lightness).to_s).to eq(hex)
      end
    end
  end

  describe "#mix_white" do
    it "matches the built-in palettes' primary-light, the base mixed with 25% white (_themes.css)" do
      expect(described_class.new("#fe9263").mix_white(described_class::LIGHT_MIX).to_s).to eq("#fead8a")
      expect(described_class.new("#afcf5a").mix_white(described_class::LIGHT_MIX).to_s).to eq("#c3db83")
      expect(described_class.new("#74d4ec").mix_white(described_class::LIGHT_MIX).to_s).to eq("#97dff1")
    end

    it "returns the colour at 0 and white at 1" do
      colour = described_class.new("#123456")
      expect(colour.mix_white(0).to_s).to eq("#123456")
      expect(colour.mix_white(1).to_s).to eq("#ffffff")
    end
  end

  describe "#shade" do
    it "lands within a few RGB steps of the built-in pink ramp's hand-tuned shades" do
      colour = described_class.new("#f19089")
      # built-in pink ramp: deep #e66f67, dark #d65a52, strong #b5443d
      expect(colour.shade(described_class::SHADE_FACTORS[:deep]).to_s).to eq("#e47169")
      expect(colour.shade(described_class::SHADE_FACTORS[:dark]).to_s).to eq("#d65a51")
      expect(colour.shade(described_class::SHADE_FACTORS[:strong]).to_s).to eq("#ba443c")
    end

    it "gets strictly darker as the factor drops" do
      colour = described_class.new("#afcf5a")
      lightness = described_class::SHADE_FACTORS.values.map { |factor| colour.shade(factor).to_hsl[2] }
      expect(lightness).to eq(lightness.sort.reverse)
    end
  end
end
