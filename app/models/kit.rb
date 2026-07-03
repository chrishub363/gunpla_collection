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
class Kit < ApplicationRecord
  STATUSES = %w[wishlist unbuilt in_progress completed].freeze

  # Whether a kit could be bought through a normal retail storefront. Anything
  # carrying a distribution/exclusivity marker in its ScaleMates subtitle
  # (P-Bandai, Gundam Base, event/web-shop limited runs) is "limited"; the rest
  # is "retail". Kept coarse on purpose — see classify_availability. [[external-links-expansion]]
  AVAILABILITIES = %w[retail limited].freeze

  GRADE_NORMALIZATION = {
    "High Grade" => "HG",
    "HG" => "HG",
    "Real Grade" => "RG",
    "RG" => "RG",
    "Master Grade" => "MG",
    "MG" => "MG",
    "Master Grade Super Deformed" => "MGSD",
    "MGSD" => "MGSD",
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
  validates :availability, inclusion: { in: AVAILABILITIES }

  before_save :normalize_grade_abbr

  # Grade prefixes as they lead a ScaleMates h1. ScaleMates writes grades both
  # spelled out ("Real Grade RX-0 …") and — far more often — abbreviated,
  # including sub-line variants (HGUC/HGAC/HGFC…) and the odd parenthesized
  # "(HG)". Patterns are anchored to the start and tried in order, so the more
  # specific ones must come first: MGSD before MG, and every abbreviation only
  # ever leads an actual gunpla grade line so non-grade kits (30MM, Megami,
  # Haropla, Macross, …) correctly fall through to nil.
  GRADE_PATTERNS = {
    /\AMGSD\b/i                        => "Master Grade Super Deformed",
    /\AMaster Grade Super Deformed\b/i => "Master Grade Super Deformed",
    # HG + all its sub-lines (HGUC, HGAC, HGFC, HGBF, HG/Figure-rise…), plain and
    # parenthesized. "High" never starts with the letters "HG", so no overlap.
    /\A\(?HG/i                         => "High Grade",
    /\AHigh Grade\b/i                  => "High Grade",
    /\AMG(?:EX)?\b/i                   => "Master Grade",
    /\AMaster Grade\b/i                => "Master Grade",
    /\A\(?RG\b/i                       => "Real Grade",
    /\AReal Grade\b/i                  => "Real Grade",
    /\APG\b/i                          => "Perfect Grade",
    /\APerfect Grade\b/i               => "Perfect Grade",
    /\AEG\b/i                          => "Entry Grade",
    /\AEntry Grade\b/i                 => "Entry Grade",
    /\AFM\b/i                          => "Full Mechanics",
    /\AFull Mechanics\b/i              => "Full Mechanics",
    # SD and its sub-lines (SDCS/SDEX/SDBD…) are all Super Deformed. After MGSD.
    /\ASD/i                            => "Super Deformed",
    /\ASuper Deformed\b/i              => "Super Deformed",
    /\ANo Grade\b/i                    => "No Grade"
  }.freeze

  # Distribution/exclusivity markers that mean "not on a normal retail shelf".
  # Matched anywhere in the subtitle — ScaleMates writes these both in parens
  # ("(Premium Bandai Limited)") and bare ("Premium Bandai Limited").
  LIMITED_SUBTITLE = /\b(?:limited|exclusive|premium bandai|p-?bandai|gundam base|expo|web shop|online shop|mail order|campaign|ecopla|plamo fes)\b/i

  # Parses the grade out of a scraped ScaleMates h1; nil when none leads it.
  def self.parse_grade(h1)
    return nil if h1.blank?

    GRADE_PATTERNS.each { |pattern, name| return name if h1.match?(pattern) }
    nil
  end

  # Coarsely buckets a scraped subtitle into retail vs limited. Refine here (and
  # re-run db:seed) to split channels back out — the raw subtitle is preserved in
  # enriched_kits.json, so no re-scrape is needed.
  def self.classify_availability(subtitle)
    subtitle.to_s.match?(LIMITED_SUBTITLE) ? "limited" : "retail"
  end

  scope :collection, -> { where.not(status: "wishlist") }
  scope :wishlist, -> { where(status: "wishlist") }
  scope :completed, -> { where(status: "completed") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :unbuilt, -> { where(status: "unbuilt") }

  def filter_text
    [ title, full_title, brand, scale, grade, topic ].compact.join(" ").downcase
  end

  private

  def normalize_grade_abbr
    self.grade_abbr = GRADE_NORMALIZATION[grade]
  end
end
