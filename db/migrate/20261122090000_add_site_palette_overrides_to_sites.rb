# frozen_string_literal: true

# Per-site palette overrides: a site admin sets hex colors in admin (no build
# step) and the layout renders them as an unlayered :root <style> on top of
# the picked theme (Site#palette_css, Views::Layouts::Application). Nullable:
# NULL means "use the theme's palette".
class AddSitePaletteOverridesToSites < ActiveRecord::Migration[8.1]
  # Separate add_columns so strong_migrations can check each; it can't see inside change_table
  def change
    add_column :sites, :primary_color, :string # rubocop:disable Rails/BulkChangeTable
    add_column :sites, :secondary_color, :string
  end
end
