# Seeds

Running `bin/setup` or `bin/rails db:seed` populates the database with realistic development data using the Normal Island fictional geography. Seeds are **idempotent** (safe to re-run) and **additive** (layer alongside existing data, e.g. after cloning a production database).

## What gets created

- **Neighbourhoods**: Full Normal Island hierarchy (country, 2 regions, 2 counties, 3 districts, 8 wards), plus the US hierarchy for this deployment (United States > New York > Monroe County > Scottsville, ZIP 14546)
- **Tags**: 21 categories (e.g. Health & Wellbeing, Food, LGBTQ+, Arts & Culture), 6 facilities, 3 partnerships
- **Sites**: 4 published sites — 3 at different geographic levels (country, county, district) and 1 partnership site (Normal Island Book Clubs) — each with hero images, logos, and themes. Plus one unpublished default site.
- **Users**: 9 users covering every admin role, with avatars (see table below). All passwords are `password`.
- **Partners**: ~100 partners across all 8 wards, each with address, categories, social media links, opening times, phone numbers (US NANP format, 585 area code), and images
- **Events**: 600+ events per partner (mix of past and future dates) with 50 different event types

## Seed users

| Email                                 | Role                | Scope                   |
| ------------------------------------- | ------------------- | ----------------------- |
| root@placecal.org                     | Root                | Everything              |
| editor@placecal.org                   | Editor              | All news articles       |
| neighbourhood-admin@placecal.org      | Neighbourhood admin | Millbrook district      |
| partner-admin@placecal.org            | Partner admin       | Riverside Community Hub |
| site-admin-normal-island@placecal.org | Site admin          | Normal Island site      |
| site-admin-coastshire@placecal.org    | Site admin          | Coastshire site         |
| site-admin-millbrook@placecal.org     | Site admin          | Millbrook site          |
| site-admin-book-clubs@placecal.org    | Site admin          | Book Clubs site         |
| citizen@placecal.org                  | Citizen             | No admin access         |

## Sites in development

After seeding, these sites are available:

| Site                     | URL                              | Type        |
| ------------------------ | -------------------------------- | ----------- |
| Normal Island            | http://normal-island.lvh.me:3000 | Country     |
| Coastshire               | http://coastshire.lvh.me:3000    | County      |
| Millbrook                | http://millbrook.lvh.me:3000     | District    |
| Normal Island Book Clubs | http://book-clubs.lvh.me:3000    | Partnership |
| Scottsville              | http://scottsville.lvh.me:3000   | District    |
| Admin                    | http://admin.lvh.me:3000         | —           |

## Normal Island

Tests and seeds use a fictional geography called "Normal Island" (country code: ZZ, a user-assigned ISO 3166 code) to avoid conflicts with real UK data. See `lib/normal_island.rb` for the full data structure and `doc/testing-guide.md` for guidance on writing tests.

The geography hierarchy:

```
Country: Normal Island (ZZ)
├── Region: Northvale
│   └── County: Greater Millbrook
│       ├── District: Millbrook
│       │   ├── Ward: Riverside
│       │   ├── Ward: Oldtown
│       │   ├── Ward: Greenfield
│       │   └── Ward: Harbourside
│       └── District: Ashdale
│           ├── Ward: Hillcrest
│           └── Ward: Valleyview
└── Region: Southmere
    └── County: Coastshire
        └── District: Seaview
            ├── Ward: Cliffside
            └── Ward: Beachfront
```

## Geocoding

Seeds use a custom geocoder lookup (`Geocoder::Lookup::NormalIsland`) that handles Normal Island's ZZ-prefix postcodes locally without hitting any external API. Real UK postcodes are delegated to postcodes.io as normal. This lookup is active in all environments, so Normal Island data works in development, test, and even alongside real UK data in production.

The lookup lives at `lib/normal_island/geocoder_lookup.rb` and is registered in `config/initializers/geocoder.rb`.

## US geographies (Scottsville, NY)

This deployment runs for Scottsville, NY, USA, so seeds also build a small US hierarchy: **United States (country) > New York (region) > Monroe County (county) > Scottsville (district, `unit_code_value` = ZIP `14546`)**. See `db/seeds/002_scottsville.rb`.

US ZIP codes are resolved by `UsZipLookup` (`app/services/us_zip_lookup.rb`), which reads `config/geo/us_zips.yml` first — ZIPs listed there (14546 is pinned) resolve locally with no network call — and falls back to zippopotam.us in production for any other ZIP. The lookup returns the same postcodes.io-shaped result the address pipeline expects, using the ZIP itself as the `admin_ward`/`admin_district` code so it maps to the seeded neighbourhood.

To cover more area: add the ZIP (with place, county, and a representative lat/long) to `config/geo/us_zips.yml`, re-run `bin/rails db:seed`, and the new district appears under Monroe County. `rake neighbourhoods:import` (`NeighbourhoodImporter`) imports UK ONS boundary data only — it is not used for US geographies.
