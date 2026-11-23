# frozen_string_literal: true

# Launch sites for the Scottsville, NY deployment: one site, anchored to the
# town-level district seeded by db/seeds/002_scottsville.rb. Add a town, add a
# site here anchored to its district (see config/geo/us_zips.yml).
module SeedSites
  def self.run
    $stdout.puts 'Sites'

    district = Neighbourhood.find_by(name: 'Scottsville', unit: 'district')
    raise 'Seed db/seeds/002_scottsville.rb first — no Scottsville district found' unless district

    site = Site.find_or_create_by!(slug: 'scottsville') do |s|
      s.name = 'Scottsville'
      s.tagline = "What's on in Scottsville, NY"
      s.place_name = 'Scottsville, NY'
      s.hero_text = 'Everything happening in Scottsville, NY'
      s.theme = :pink
      s.is_published = true
    end
    site.update!(name: 'Scottsville', tagline: "What's on in Scottsville, NY",
                 place_name: 'Scottsville, NY', hero_text: 'Everything happening in Scottsville, NY',
                 is_published: true)

    link = SitesNeighbourhood.find_by(site:, neighbourhood: district)
    if link
      link.update!(relation_type: 'Primary')
    else
      SitesNeighbourhood.create!(site:, neighbourhood: district, relation_type: 'Primary')
    end

    $stdout.puts "  Site: #{site.name} (#{site.slug}) anchored to #{district.name}"
  end
end

SeedSites.run
