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
FactoryBot.define do
  factory :kit do
    sequence(:title) { |n| "Test Kit #{n}" }
    status { "unbuilt" }
    brand { "Bandai Spirits" }
    scale { "1:144" }
    grade { "High Grade" }
    # grade_abbr is derived from grade by a before_save callback
  end
end
