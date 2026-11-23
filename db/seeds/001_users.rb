# frozen_string_literal: true

# Launch users for the Scottsville, NY deployment.
# Neighbourhood associations are wired at the end of db/seeds/006_events.rb,
# once the neighbourhood rows exist.
module SeedUsers
  USERS = [
    { email: 'admin@scottsville.example', first_name: 'Root', last_name: 'Admin', role: 'root' },
    # A citizen with the Scottsville district attached is a neighbourhood admin
    { email: 'collective@scottsville.example', first_name: 'Launch', last_name: 'Collective',
      role: 'citizen', neighbourhood_name: 'Scottsville' }
  ].freeze

  def self.run
    $stdout.puts 'Users'

    USERS.each do |data|
      next if User.exists?(email: data[:email])

      User.create!(
        email: data[:email],
        password: 'password',
        password_confirmation: 'password',
        first_name: data[:first_name],
        last_name: data[:last_name],
        role: data[:role] || 'citizen'
      )
      $stdout.puts "  Created user: #{data[:first_name]} #{data[:last_name]} (#{data[:email]})"
    end
  end
end

SeedUsers.run
