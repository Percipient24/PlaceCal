# frozen_string_literal: true

# The per-site palette override: nullable hex colors (primary_color,
# secondary_color) set in admin with no build step, rendered by
# Views::Layouts::Application as an unlayered :root <style> on top of the
# picked theme (see #palette_css and the override contract at the top of
# app/tailwind/public/_theme.css).
module SitePalette
  extend ActiveSupport::Concern

  included do
    # Declared here rather than in Site so the normalizes below is not wiped:
    # an attribute declaration after a normalizes replaces it.
    attribute :primary_color, :string # nullable
    attribute :secondary_color, :string # nullable
    # Stored downcased; a blank field saves as NULL, which means "use the
    # theme's palette" (see #palette_css).
    normalizes :primary_color, :secondary_color, with: ->(value) { value.presence&.downcase }
    # Hex only; blank means "use the theme's".
    validates :primary_color, :secondary_color, format: { with: PlaceCal::HexColour::FORMAT }, allow_blank: true
  end

  # The palette override as a CSS block: an unlayered :root rule, which wins
  # over both the data-theme palettes (tokens layer) and an extension theme's
  # unlayered :root (same specificity, but the layout renders it later in
  # <head>). A blank column means "use the theme": primary overrides
  # --color-primary/-light, and secondary overrides the --color-secondary ramp,
  # falling back to primary when blank — the built-in themes in _themes.css all
  # use the primary base as secondary. Derived shades approximate the built-in
  # palettes' contrast steps; there is no WCAG contrast check on admin-chosen
  # colors.
  #
  # @return [String, nil] a :root CSS block, or nil when neither color is set
  def palette_css
    primary = PlaceCal::HexColour.parse(primary_color)
    secondary = PlaceCal::HexColour.parse(secondary_color) || primary
    return if primary.nil? && secondary.nil?

    declarations = []
    if primary
      declarations << "--color-primary: #{primary};"
      declarations << "--color-primary-light: #{primary.mix_white(PlaceCal::HexColour::LIGHT_MIX)};"
    end
    if secondary
      declarations << "--color-secondary: #{secondary};"
      PlaceCal::HexColour::SHADE_FACTORS.each do |name, factor|
        declarations << "--color-secondary-#{name}: #{secondary.shade(factor)};"
      end
    end
    ":root {\n  #{declarations.join("\n  ")}\n}"
  end
end
