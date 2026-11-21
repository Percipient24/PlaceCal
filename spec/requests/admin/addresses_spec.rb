# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Addresses", type: :request do
  describe "GET /addresses/lookup" do
    let(:url) { lookup_admin_addresses_url(host: admin_host) }

    context "as an unauthenticated user" do
      it "redirects to login" do
        get url, params: { postcode: "14546" }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "as a citizen user" do
      let(:user) { create(:citizen_user) }

      before { sign_in user }

      it "is not authorized" do
        get url, params: { postcode: "14546" }
        expect(response).to redirect_to(admin_root_url(host: admin_host))
      end
    end

    context "as a root user" do
      let(:user) { create(:root_user) }

      before { sign_in user }

      it "returns the ZIP centroid for a locally-known ZIP (test env stays hermetic)" do
        get url, params: { postcode: "14546", street: "61 Main Street", city: "Scottsville" }
        expect(response).to be_successful
        json = response.parsed_body
        expect(json["postcode"]).to eq("14546")
        expect(json["latitude"]).to eq(43.0246)
        expect(json["longitude"]).to eq(-77.7743)
      end

      it "accepts a ZIP+4 and returns the 5-digit ZIP" do
        get url, params: { postcode: "14546-1234" }
        expect(response).to be_successful
        expect(response.parsed_body["postcode"]).to eq("14546")
      end

      it "passes street and city through to the lookup" do
        allow(PostcodeLookup).to receive(:call).and_return({ "postcode" => "14546", "latitude" => 1.0, "longitude" => 2.0 })
        get url, params: { postcode: "14546", street: "61 Main Street", city: "Scottsville" }
        expect(PostcodeLookup).to have_received(:call).with("14546", street: "61 Main Street", city: "Scottsville")
      end

      it "returns 404 when the postcode doesn't exist" do
        allow(PostcodeLookup).to receive(:call).and_return(nil)
        get url, params: { postcode: "00000" }
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["error"]).to be_present
      end

      it "returns 503 when the lookup service is unavailable" do
        allow(PostcodeLookup).to receive(:call).and_raise(PostcodeLookup::Unavailable, "down")
        get url, params: { postcode: "14546" }
        expect(response).to have_http_status(:service_unavailable)
        expect(response.parsed_body["error"]).to be_present
      end
    end

    context "as a partner admin" do
      let(:user) { create(:partner_admin) }

      before { sign_in user }

      it "can look up a ZIP" do
        get url, params: { postcode: "14546" }
        expect(response).to be_successful
      end
    end
  end
end
