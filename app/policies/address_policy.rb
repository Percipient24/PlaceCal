# frozen_string_literal: true

class AddressPolicy < ApplicationPolicy
  # The admin partner form's pin map looks up best-guess coordinates for an
  # address. Anyone who can reach the partner form can use it.
  def lookup?
    user.root? || user.neighbourhood_admin? || user.partnership_admin? || user.partner_admin?
  end
end
