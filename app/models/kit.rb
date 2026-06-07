# == Schema Information
#
# Table name: kits
#
#  id             :integer          not null, primary key
#  brand          :string
#  full_title     :string
#  grade          :string
#  grade_abbr     :string
#  image_url      :string
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
#  index_kits_on_scalemates_id  (scalemates_id) UNIQUE
#  index_kits_on_series         (series)
#  index_kits_on_status         (status)
#
class Kit < ApplicationRecord
  STATUSES = %w[wishlist unbuilt in_progress completed].freeze

  GRADE_NORMALIZATION = {
    "High Grade" => "HG",
    "HG" => "HG",
    "Real Grade" => "RG",
    "RG" => "RG",
    "Master Grade" => "MG",
    "MG" => "MG",
    "Perfect Grade" => "PG",
    "PG" => "PG",
    "Super Deformed" => "SD",
    "SD" => "SD",
    "Full Mechanics" => "FM",
    "FM" => "FM",
    "Entry Grade" => "EG",
    "EG" => "EG",
    "No Grade" => "NG",
    "NG" => "NG"
  }.freeze

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }

  before_save :normalize_grade_abbr

  scope :collection, -> { where.not(status: "wishlist") }
  scope :wishlist, -> { where(status: "wishlist") }
  scope :completed, -> { where(status: "completed") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :unbuilt, -> { where(status: "unbuilt") }

  private

  def normalize_grade_abbr
    self.grade_abbr = GRADE_NORMALIZATION[grade]
  end
end
