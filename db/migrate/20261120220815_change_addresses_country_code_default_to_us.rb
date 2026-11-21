# frozen_string_literal: true

# This deployment runs for the US (Scottsville, NY), so new addresses default to
# country_code "US" instead of "UK". Existing rows are left as they are.
class ChangeAddressesCountryCodeDefaultToUs < ActiveRecord::Migration[8.1]
  def change
    change_column_default :addresses, :country_code, from: 'UK', to: 'US'
  end
end
