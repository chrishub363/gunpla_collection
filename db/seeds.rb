require "json"

puts "Seeding kits..."

enriched_path = Rails.root.join("db/seeds/enriched_kits.json")
kits_data = JSON.parse(enriched_path.read)

Kit.destroy_all

# enriched_kits.json holds the raw ScaleMates page data; the processing lives
# here so it can be refined and re-seeded without re-scraping. grade is parsed
# from the h1, availability classified from the subtitle, full_title taken from
# the raw og:title. grade_abbr is normalized in a Kit before_save.
kits_data.each do |data|
  Kit.create!(
    title:          data["title"],
    full_title:     data["og_title"],
    grade:          Kit.parse_grade(data["h1"]),
    scale:          data["scale"],
    brand:          data["brand"],
    topic:          data["topic"],
    image:          data["image"],
    availability:   Kit.classify_availability(data["subtitle"]),
    scalemates_id:  data["scalemates_id"],
    scalemates_url: data["scalemates_url"],
    status:         data["status"],
  )
end

puts "Done! #{Kit.count} kits seeded."
