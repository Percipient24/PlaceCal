# frozen_string_literal: true

module PlaceCal
  # A hex colour (#rgb, #rrggbb or #rrggbbaa) parsed to its RGB channels, with
  # the two derivations the per-site palette override needs (Site#palette_css):
  # a white mix for --color-primary-light, and darker HSL shades for the
  # --color-secondary-* ramp, approximating the steps the built-in palettes in
  # app/tailwind/public/_themes.css were tuned to.
  class HexColour
    # Anchored pattern for Ruby-side validation (Site's format validation).
    FORMAT = /\A#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})\z/i
    # The same pattern for an HTML pattern attribute, which anchors implicitly.
    HTML_PATTERN = '#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})'

    # Fraction of the way toward white for --color-primary-light: the built-in
    # themes mix the base colour with 25% white (see _themes.css).
    LIGHT_MIX = 0.25
    # HSL saturation/lightness factors for the --color-secondary-* ramp. Both
    # channels scale together, which lands within a few RGB steps of the
    # built-in palettes' hand-tuned deep/dark/strong shades.
    SHADE_FACTORS = { deep: 0.88, dark: 0.78, strong: 0.65 }.freeze

    attr_reader :red, :green, :blue

    def self.valid?(value)
      value.is_a?(String) && value.match?(FORMAT)
    end

    # @return [HexColour, nil] nil for a blank value; raises on anything else invalid
    def self.parse(value)
      return nil if value.blank?

      new(value)
    end

    # @param hex [String] #rgb, #rrggbb or #rrggbbaa
    # @raise [ArgumentError] unless the value matches FORMAT
    def initialize(hex)
      raise ArgumentError, "#{hex.inspect} is not a hex colour (expected #rgb, #rrggbb or #rrggbbaa)" unless self.class.valid?(hex)

      digits = hex.delete_prefix('#').downcase
      digits = digits.chars.map { |c| c * 2 }.join if digits.length == 3
      # An 8-digit hex carries alpha; palette tokens are opaque, so it is dropped.
      @red = digits[0, 2].to_i(16)
      @green = digits[2, 2].to_i(16)
      @blue = digits[4, 2].to_i(16)
    end

    # @return [String] the 6-digit form of the channels, e.g. "#f19089"
    def self.rgb_hex(red, green, blue) = format('#%<r>02x%<g>02x%<b>02x', r: red, g: green, b: blue)

    # @return [HexColour]
    def self.from_rgb(red, green, blue) = new(rgb_hex(red, green, blue))

    # The normalised 6-digit form, e.g. "#aabbcc".
    def to_s = self.class.rgb_hex(red, green, blue)

    # @return [Array(Integer, Integer, Integer)] channels 0-255
    def to_rgb = [red, green, blue]

    # @return [Array(Float, Float, Float)] hue 0-360, saturation 0-1, lightness 0-1
    def to_hsl
      r, g, b = to_rgb.map { |channel| channel / 255.0 }
      max = [r, g, b].max
      min = [r, g, b].min
      lightness = (max + min) / 2
      return [0.0, 0.0, lightness] if max == min

      delta = max - min
      saturation = lightness > 0.5 ? delta / (2 - max - min) : delta / (max + min)
      hue =
        case max
        when r then ((g - b) / delta) + (g < b ? 6 : 0)
        when g then ((b - r) / delta) + 2
        else ((r - g) / delta) + 4
        end
      [hue * 60, saturation, lightness]
    end

    # @return [HexColour]
    def self.from_hsl(hue, saturation, lightness)
      hue %= 360
      chroma = (1 - ((2 * lightness) - 1).abs) * saturation
      x = chroma * (1 - (((hue / 60) % 2) - 1).abs)
      m = lightness - (chroma / 2)
      r, g, b =
        if hue < 60 then [chroma, x, 0.0]
        elsif hue < 120 then [x, chroma, 0.0]
        elsif hue < 180 then [0.0, chroma, x]
        elsif hue < 240 then [0.0, x, chroma]
        elsif hue < 300 then [x, 0.0, chroma]
        else [chroma, 0.0, x]
        end
      from_rgb(((r + m) * 255).round, ((g + m) * 255).round, ((b + m) * 255).round)
    end

    # @param fraction [Float] 0 keeps the colour, 1 is white
    # @return [HexColour]
    def mix_white(fraction)
      mixed = to_rgb.map { |channel| (channel + ((255 - channel) * fraction)).round }
      self.class.from_rgb(*mixed)
    end

    # A darker shade: saturation and lightness both scaled by factor in HSL
    # space, approximating the built-in palettes' deep/dark/strong steps.
    #
    # @param factor [Float] e.g. SHADE_FACTORS values
    # @return [HexColour]
    def shade(factor)
      hue, saturation, lightness = to_hsl
      self.class.from_hsl(hue, saturation * factor, lightness * factor)
    end
  end
end
