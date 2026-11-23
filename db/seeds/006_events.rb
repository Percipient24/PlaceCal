# frozen_string_literal: true

# Launch events for the Scottsville, NY deployment, plus the user/neighbourhood
# wiring that needs those rows to exist.
#
# Events show the organiser/place split: "Board Games Night" is organised by
# Scottsville Board Gamers but takes place at the American Legion (place), with
# the venue's address. "Storytime" is organised by and held at the Library.
module SeedEvents
  def self.at(day_name, hour, minute = 0)
    date = Date.current.next_occurring(day_name)
    Time.zone.local(date.year, date.month, date.day, hour, minute)
  end

  def self.run
    $stdout.puts 'Events'

    library = Partner.find_by(name: 'Scottsville Free Library')
    legion = Partner.find_by(name: 'Scottsville American Legion')
    market = Partner.find_by(name: "Scottsville Farmers' Market")
    gamers = Partner.find_by(name: 'Scottsville Board Gamers')

    [
      { summary: 'Board Games Night', organiser: gamers, place: legion,
        dtstart: at(:friday, 19), dtend: at(:friday, 22),
        description: 'Casual board games at the Legion hall. All welcome, no experience needed.' },
      { summary: 'Board Games at the Library', organiser: gamers, place: library,
        dtstart: at(:saturday, 14), dtend: at(:saturday, 16),
        description: 'Family board game afternoon in the library meeting room.' },
      { summary: "Children's Storytime", organiser: library, place: library,
        dtstart: at(:saturday, 10, 30), dtend: at(:saturday, 11, 15),
        description: 'Weekly storytime for under-5s with songs and a craft.' },
      { summary: "Farmers' Market", organiser: market, place: market,
        dtstart: at(:saturday, 9), dtend: at(:saturday, 13),
        description: 'Local produce, bakes and crafts on Main Street.' }
    ].each do |data|
      place = data[:place]
      event = Event.find_or_create_by!(summary: data[:summary], dtstart: data[:dtstart]) do |e|
        e.organiser = data[:organiser]
        e.place = place
        e.address = place&.address
        e.dtend = data[:dtend]
        e.description = data[:description]
      end
      $stdout.puts "  #{event.previously_new_record? ? 'Created' : 'Found'} event: #{event.summary} " \
                   "(organiser: #{event.organiser&.name}, place: #{event.place&.name})"
    end

    # Wire the launch-collective user as neighbourhood admin for Scottsville
    collective = User.find_by(email: 'collective@scottsville.example')
    district = Neighbourhood.find_by(name: 'Scottsville', unit: 'district')
    return unless collective && district && collective.neighbourhoods.exclude?(district)

    collective.neighbourhoods << district
    $stdout.puts "  Assigned #{collective.email} as neighbourhood admin for #{district.name}"
  end
end

SeedEvents.run
