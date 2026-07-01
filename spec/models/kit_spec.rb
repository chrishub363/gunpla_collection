require "rails_helper"

RSpec.describe Kit, type: :model do
  describe "#filter_text" do
    it "joins all searchable fields lowercased" do
      kit = Kit.new(title: "Strike Gundam", full_title: "ZGMF-X105", brand: "Bandai", scale: "1:144", grade: "HG", topic: "SEED")
      text = kit.filter_text

      expect(text).to eq(text.downcase)
      expect(text).to include("strike gundam")
      expect(text).to include("zgmf-x105")
    end

    it "skips nil fields" do
      kit = Kit.new(title: "Strike Gundam", topic: nil)

      expect(kit.filter_text).to eq("strike gundam")
    end
  end

  describe "normalize_grade_abbr callback" do
    it "sets grade_abbr from grade on save" do
      kit = create(:kit, grade: "Real Grade")

      expect(kit.grade_abbr).to eq("RG")
    end

    it "maps Master Grade Super Deformed and Super Deformed grades" do
      mgsd = create(:kit, grade: "Master Grade Super Deformed")
      sd   = create(:kit, grade: "Super Deformed")

      expect(mgsd.grade_abbr).to eq("MGSD")
      expect(sd.grade_abbr).to eq("SD")
    end

    it "leaves grade_abbr nil when grade is unrecognized" do
      kit = create(:kit, grade: "Unknown Grade")

      expect(kit.grade_abbr).to be_nil
    end
  end

  describe "validations" do
    it "is invalid without a title" do
      kit = Kit.new(status: "unbuilt")

      expect(kit).not_to be_valid
      expect(kit.errors[:title]).to include("can't be blank")
    end

    it "is invalid with an unrecognized status" do
      kit = Kit.new(title: "Test Kit", status: "broken")

      expect(kit).not_to be_valid
    end
  end

  describe "scopes" do
    it "collection excludes wishlist kits" do
      wishlist_kit = create(:kit, status: "wishlist")
      owned_kit = create(:kit, status: "unbuilt")

      expect(Kit.collection).to include(owned_kit)
      expect(Kit.collection).not_to include(wishlist_kit)
    end

    it "unbuilt returns only unbuilt kits" do
      unbuilt_kit = create(:kit, status: "unbuilt")
      completed_kit = create(:kit, status: "completed")

      expect(Kit.unbuilt).to include(unbuilt_kit)
      expect(Kit.unbuilt).not_to include(completed_kit)
    end

    it "wishlist returns only wishlist kits" do
      wishlist_kit = create(:kit, status: "wishlist")
      owned_kit = create(:kit, status: "unbuilt")

      expect(Kit.wishlist).to include(wishlist_kit)
      expect(Kit.wishlist).not_to include(owned_kit)
    end
  end
end
