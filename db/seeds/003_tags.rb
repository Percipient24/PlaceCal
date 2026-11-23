# frozen_string_literal: true

# Launch tags for the Scottsville, NY deployment: Categories only.
# Partnerships are deliberately not seeded at launch — when a group of partners
# needs to be first-class (its own Site, its own admins), add a tag with
# type 'Partnership' here instead of overloading a Category. Keep one row per
# name: never create the same name as both a Category and a Partnership.
module SeedTags
  CATEGORIES = [
    'Community Events',
    'Games & Entertainment',
    'Education & Learning',
    'Art, Music & Culture',
    'Sports & Athletics',
    'Food'
  ].freeze

  def self.run
    $stdout.puts 'Tags (categories)'

    CATEGORIES.each do |name|
      tag = Tag.find_or_create_by!(name:, type: 'Category') do |t|
        t.slug = name.parameterize
        t.description = "Events and activities related to #{name.downcase}"
      end
      $stdout.puts "  #{tag.previously_new_record? ? 'Created' : 'Found'} category: #{tag.name}"
    end
  end
end

SeedTags.run
