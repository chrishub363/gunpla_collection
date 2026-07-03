require "rails_helper"

# == Schema Information
#
# Table name: kits
#
#  id             :integer          not null, primary key
#  availability   :string           default("retail"), not null
#  brand          :string
#  full_title     :string
#  grade          :string
#  grade_abbr     :string
#  image          :string
#  scale          :string
#  scalemates_url :string
#  series         :string
#  status         :string           default("unbuilt"), not null
#  title          :string           not null
#  topic          :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  scalemates_id  :integer
#
# Indexes
#
#  index_kits_on_availability   (availability)
#  index_kits_on_grade_abbr     (grade_abbr)
#  index_kits_on_scalemates_id  (scalemates_id)
#  index_kits_on_series         (series)
#  index_kits_on_status         (status)
#
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

  describe ".parse_grade" do
    it "reads spelled-out grade prefixes" do
      expect(Kit.parse_grade("Real Grade RX-0 Unicorn Gundam 03 Phenex")).to eq("Real Grade")
      expect(Kit.parse_grade("Master Grade RX-78-2 Gundam Ver. 3.0")).to eq("Master Grade")
    end

    it "reads abbreviated prefixes and their sub-lines" do
      expect(Kit.parse_grade("HG Gundam Aerial")).to eq("High Grade")
      expect(Kit.parse_grade("HGUC Gundam 0083 MS-06F-2 Zaku II F2")).to eq("High Grade")
      expect(Kit.parse_grade("HGAC XXXG-01W Wing Gundam")).to eq("High Grade")
      expect(Kit.parse_grade("(HG) Gundam Barbatos")).to eq("High Grade")
      expect(Kit.parse_grade("MG Nu Gundam Ver.Ka")).to eq("Master Grade")
      expect(Kit.parse_grade("MGEX Strike Freedom Gundam")).to eq("Master Grade")
      expect(Kit.parse_grade("RG Nu Gundam")).to eq("Real Grade")
      expect(Kit.parse_grade("PG Unleashed RX-78-2 Gundam")).to eq("Perfect Grade")
      expect(Kit.parse_grade("EG RX-78-2 Gundam")).to eq("Entry Grade")
    end

    it "matches MGSD before plain Master Grade" do
      expect(Kit.parse_grade("MGSD Freedom Gundam")).to eq("Master Grade Super Deformed")
    end

    it "treats the SD sub-lines as Super Deformed" do
      expect(Kit.parse_grade("SD Gundam EX-Standard Nu Gundam")).to eq("Super Deformed")
      expect(Kit.parse_grade("SDCS Nu Gundam")).to eq("Super Deformed")
    end

    it "returns nil for non-grade lines and blanks" do
      expect(Kit.parse_grade("30MM eEXM-21 Rabiot")).to be_nil
      expect(Kit.parse_grade("Megami Device Asra Ninja")).to be_nil
      expect(Kit.parse_grade("Millennium Falcon [Standard Ver.]")).to be_nil
      expect(Kit.parse_grade(nil)).to be_nil
      expect(Kit.parse_grade("")).to be_nil
    end
  end

  describe ".classify_availability" do
    it "flags distribution/exclusivity markers as limited" do
      expect(Kit.classify_availability("Full Psycho-Frame Prototype Mobile Suit (Premium Bandai Limited)")).to eq("limited")
      expect(Kit.classify_availability("Premium Bandai Limited")).to eq("limited")
      expect(Kit.classify_availability("Limited Item")).to eq("limited")
      expect(Kit.classify_availability("The Gundam Base Limited")).to eq("limited")
      expect(Kit.classify_availability("Hobby On-line Shop Limited")).to eq("limited")
    end

    it "treats an ordinary or missing subtitle as retail" do
      expect(Kit.classify_availability("Principality of Zeon Mass Productive Mobile Suit")).to eq("retail")
      expect(Kit.classify_availability(nil)).to eq("retail")
      expect(Kit.classify_availability("")).to eq("retail")
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

    it "is invalid with an unrecognized availability" do
      kit = Kit.new(title: "Test Kit", availability: "somewhere")

      expect(kit).not_to be_valid
      expect(kit.errors[:availability]).to be_present
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
