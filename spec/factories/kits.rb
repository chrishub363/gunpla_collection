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
