# == Schema Information
#
# Table name: kits
#
#  id             :integer          not null, primary key
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
#  index_kits_on_grade_abbr     (grade_abbr)
#  index_kits_on_scalemates_id  (scalemates_id)
#  index_kits_on_series         (series)
#  index_kits_on_status         (status)
#
require "test_helper"

class KitTest < ActiveSupport::TestCase
  # -- filter_text --

  test "filter_text joins all searchable fields lowercased" do
    kit = Kit.new(title: "Strike Gundam", full_title: "ZGMF-X105", brand: "Bandai", scale: "1:144", grade: "HG", topic: "SEED")
    text = kit.filter_text

    assert_equal text, text.downcase
    assert_includes text, "strike gundam"
    assert_includes text, "zgmf-x105"
  end

  test "filter_text skips nil fields" do
    kit = Kit.new(title: "Strike Gundam", topic: nil)

    assert_equal "strike gundam", kit.filter_text
  end

  # -- normalize_grade_abbr callback --

  test "sets grade_abbr from grade on save" do
    kit = Kit.create!(title: "Test Kit", grade: "Real Grade", status: "unbuilt")

    assert_equal "RG", kit.grade_abbr
  end

  test "maps Master Grade Super Deformed and Super Deformed grades" do
    mgsd = Kit.create!(title: "Barbatos", grade: "Master Grade Super Deformed", status: "unbuilt")
    sd   = Kit.create!(title: "Sazabi", grade: "Super Deformed", status: "unbuilt")

    assert_equal "MGSD", mgsd.grade_abbr
    assert_equal "SD", sd.grade_abbr
  end

  test "grade_abbr is nil when grade is unrecognized" do
    kit = Kit.create!(title: "Test Kit", grade: "Unknown Grade", status: "unbuilt")

    assert_nil kit.grade_abbr
  end

  # -- validations --

  test "invalid without title" do
    kit = Kit.new(status: "unbuilt")

    assert_not kit.valid?
    assert_includes kit.errors[:title], "can't be blank"
  end

  test "invalid with unrecognized status" do
    kit = Kit.new(title: "Test Kit", status: "broken")

    assert_not kit.valid?
  end

  # -- scopes --

  test "collection excludes wishlist kits" do
    wishlist_kit = Kit.create!(title: "Wishlist Kit", status: "wishlist")

    assert_not_includes Kit.collection, wishlist_kit
    assert_includes Kit.collection, kits(:one)
  end

  test "unbuilt scope" do
    assert_includes Kit.unbuilt, kits(:one)
    assert_not_includes Kit.unbuilt, kits(:two)
  end

  test "wishlist scope" do
    wishlist_kit = Kit.create!(title: "Wishlist Kit", status: "wishlist")

    assert_includes Kit.wishlist, wishlist_kit
    assert_not_includes Kit.wishlist, kits(:one)
  end
end
