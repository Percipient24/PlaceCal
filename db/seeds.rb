# frozen_string_literal: true

# Seed loading rules:
#
# - db/seeds/002_scottsville.rb — the geography (country / region / county /
#   town Neighbourhood rows built from config/geo/us_zips.yml) — loads in EVERY
#   environment. It is required infrastructure, not demo data: addresses
#   geocode to Neighbourhood rows by unit_code_value, so without the town row
#   every new address fails with "could not be mapped to a neighbourhood".
#   Deploys run db:prepare (migrations only), so run `bin/rails db:seed` once
#   on the production server after the first deploy.
#
# - Everything else (users, categories, the demo site, partners, events) is
#   local demo data and loads only OUTSIDE production. In production, create
#   the first root user in the console with a real password, then sites, tags,
#   partners and events through the admin UI — never seed demo rows there.
INFRASTRUCTURE_SEEDS = %w[002_scottsville.rb].freeze

Dir[Rails.root.join('db/seeds/*.rb')].sort.each do |file|
  basename = File.basename(file)
  next unless INFRASTRUCTURE_SEEDS.include?(basename) || !Rails.env.production?

  Rails.logger.debug { "Seeding from #{file.split('/').slice(-3, 3).join('/')}" }
  require file
end
