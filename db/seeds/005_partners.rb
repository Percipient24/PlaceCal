# frozen_string_literal: true

# Launch partners for the Scottsville, NY deployment — the launch collective.
#
# Two shapes to note:
# - Venues (Library, Legion, Farmers' Market) have an address (ZIP 14546 geocodes
#   to the Scottsville district) and is_a_place: true; events point at them via
#   Event#place.
# - Organisers without a fixed base (Board Gamers) have no address, only a
#   service area — Partner requires at least one of the two.
module SeedPartners
  ZIP = '14546'.freeze

  PARTNERS = [
    {
      name: 'Scottsville Free Library',
      street_address: '1 Library Way',
      is_a_place: true,
      categories: ['Education & Learning', 'Community Hubs'],
      summary: 'The village library: books, storytime, digital skills and a quiet place to sit.',
      public_email: 'hello@scottsvillelibrary.example',
      url: 'https://scottsvillelibrary.example'
    },
    {
      name: 'Scottsville American Legion',
      street_address: '150 Main Street',
      is_a_place: true,
      categories: ['Community Hubs'],
      summary: 'Legion post hall — hosts community events, dinners and club meetings. Available to hire.',
      public_phone: '(585) 555-0150'
    },
    {
      name: 'Scottsville Board Gamers',
      is_a_place: false, # no fixed base — meets at other partners' venues
      service_area: 'Scottsville',
      categories: ['Arts & Culture', 'Community Events'],
      summary: 'Casual board game nights around Scottsville, hosted at the Library and the Legion.',
      public_email: 'boardgamers@scottsville.example'
    },
    {
      name: "Scottsville Farmers' Market",
      street_address: '200 Main Street',
      is_a_place: true,
      categories: ['Food'],
      summary: 'Weekly Saturday market on Main Street with local produce, bakes and crafts.',
      public_email: 'market@scottsville.example'
    },
    {
      name: 'Scottsville Food Pantry',
      street_address: '25 Church Street',
      is_a_place: true,
      categories: ['Food', 'Community Hubs'],
      summary: 'Free food parcels and essentials every Thursday. No referral needed for a first visit.'
    }
  ].freeze

  def self.run
    $stdout.puts 'Partners'
    district = Neighbourhood.find_by(name: 'Scottsville', unit: 'district')

    PARTNERS.each do |data|
      partner = Partner.find_or_create_by!(name: data[:name]) do |p|
        p.summary = data[:summary]
        p.public_email = data[:public_email]
        p.public_phone = data[:public_phone]
        p.url = data[:url]
        p.is_a_place = data[:is_a_place] || false
        if data[:street_address]
          p.address = Address.create!(street_address: data[:street_address], postcode: ZIP, country_code: 'US')
        elsif district
          # build, don't create: the partner isn't persisted yet, and the
          # has-many autosaves the service area right after the partner saves
          p.service_areas.build(neighbourhood: district)
        end
      end

      Array(data[:categories]).each do |name|
        tag = Tag.find_by(name:, type: 'Category')
        PartnerTag.find_or_create_by!(partner:, tag:) if tag
      end

      $stdout.puts "  #{partner.previously_new_record? ? 'Created' : 'Found'} partner: #{partner.name} " \
                   "(#{partner.address ? partner.address.to_s : 'service area: Scottsville'})"
    end
  end
end

SeedPartners.run
