require "rails_helper"

RSpec.describe "Kits", type: :request do
  describe "GET /" do
    before { create(:kit) }

    it "renders successfully" do
      get root_path

      expect(response).to have_http_status(:success)
    end

    it "renders the wishlist tab" do
      get root_path, params: { tab: "wishlist" }

      expect(response).to have_http_status(:success)
    end

    it "renders with a grade filter" do
      get root_path, params: { grade: "HG" }

      expect(response).to have_http_status(:success)
    end

    it "renders with an availability filter" do
      get root_path, params: { availability: "limited" }

      expect(response).to have_http_status(:success)
    end

    it "renders the status badge as a filter link on the collection" do
      create(:kit, title: "Linkable Kit", status: "completed")

      get root_path

      expect(Capybara.string(response.body))
        .to have_link("Built", href: /status=completed/)
    end

    it "renders with a status filter" do
      get root_path, params: { status: "completed" }

      expect(response).to have_http_status(:success)
    end

    it "renders with a search query" do
      get root_path, params: { search: "Gundam" }

      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /pick" do
    it "renders successfully" do
      get pick_path

      expect(response).to have_http_status(:success)
    end

    it "shows no result without a roll param" do
      get pick_path

      expect(Capybara.string(response.body)).to have_no_css("h2")
    end

    it "picks an unbuilt kit when rolled" do
      create(:kit, status: "unbuilt")

      get pick_path, params: { roll: "1" }

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_css("h2")
    end

    it "restricts the pick to the selected grade filter" do
      # Only this RG kit exists, so it is the only pickable candidate
      create(:kit, title: "RG Aile Strike", status: "unbuilt", grade: "Real Grade")

      get pick_path, params: { roll: "1", grade: "RG" }

      expect(Capybara.string(response.body)).to have_css("h2", text: /RG Aile Strike/)
    end

    it "restricts the pick to the selected availability filter" do
      create(:kit, title: "Phenex P-Bandai", status: "unbuilt", availability: "limited")
      create(:kit, title: "Shelf Zaku", status: "unbuilt", availability: "retail")

      get pick_path, params: { roll: "1", availability: "limited" }

      expect(Capybara.string(response.body)).to have_css("h2", text: /Phenex P-Bandai/)
    end

    it "shows an empty state when no kits match" do
      get pick_path, params: { roll: "1", brand: "Nobody Makes This Brand" }

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_no_css("h2")
    end
  end
end
