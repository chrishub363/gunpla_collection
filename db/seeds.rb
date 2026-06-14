require "json"

puts "Seeding kits..."

enriched_path = Rails.root.join("db/seeds/enriched_kits.json")
kits_data = JSON.parse(enriched_path.read)

Kit.destroy_all

kits_data.each do |data|
  Kit.create!(
    title:          data["title"],
    full_title:     data["full_title"],
    grade:          data["grade"],
    scale:          data["scale"],
    brand:          data["brand"],
    topic:          data["topic"],
    image_url:      data["image_url"],
    scalemates_id:  data["scalemates_id"],
    scalemates_url: data["scalemates_url"],
    status:         data["status"],
  )
end

puts "Done! #{Kit.count} kits seeded."
