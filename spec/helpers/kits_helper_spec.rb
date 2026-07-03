require "rails_helper"

RSpec.describe KitsHelper, type: :helper do
  describe "#kit_source_link_defs" do
    it "gives retail kits a USA Gundam Store link, not P-Bandai" do
      kit = build(:kit, availability: "retail")
      labels = helper.kit_source_link_defs(kit).map { |l| l[:label] }

      expect(labels).to include("UG")
      expect(labels).not_to include("PB")
    end

    it "gives limited kits a P-Bandai link, not USA Gundam Store" do
      kit = build(:kit, availability: "limited")
      labels = helper.kit_source_link_defs(kit).map { |l| l[:label] }

      expect(labels).to include("PB")
      expect(labels).not_to include("UG")
    end

    it "always includes the wiki and eBay, and ScaleMates when a url is present" do
      kit = build(:kit, scalemates_url: "https://www.scalemates.com/kits/--1")
      labels = helper.kit_source_link_defs(kit).map { |l| l[:label] }

      expect(labels).to include("GW", "eB", "SM")
    end

    it "drops the ScaleMates link when there is no url" do
      kit = build(:kit, scalemates_url: nil)
      labels = helper.kit_source_link_defs(kit).map { |l| l[:label] }

      expect(labels).not_to include("SM")
    end

    it "builds search urls from the kit grade abbreviation and title" do
      # grade_abbr is set from grade by a before_save, so the record must be saved
      kit = create(:kit, grade: "Real Grade", title: "Nu Gundam")
      wiki = helper.kit_source_link_defs(kit).find { |l| l[:label] == "GW" }

      expect(wiki[:url]).to include("query=RG%20Nu%20Gundam")
    end

    it "scopes the P-Bandai search to the Bandai Hobby Online Shop and includes ended items" do
      kit = create(:kit, availability: "limited", grade: "Real Grade", title: "Nu Gundam")
      pb = helper.kit_source_link_defs(kit).find { |l| l[:label] == "PB" }

      expect(pb[:url]).to include("keyword=RG%20Nu%20Gundam")
      expect(pb[:url]).to include("_f_shops=05-0002")
      expect(pb[:url]).to include("_f_productStatuses=Waiting%2COn%2CEnd")
    end
  end
end
