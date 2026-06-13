require "csv"
require "json"
require "open3"
require "nokogiri"

namespace :enrich do
  desc "Scrape ScaleMates for image_url, full_title, and grade for all kits. Use enrich:kits[force] to re-enrich everything."
  task :kits, [ :mode ] => :environment do |_task, args|
    $stdout.sync = true

    force = args[:mode] == "force"

    csv_files = {
      "wishlist"    => Rails.root.join("db/seeds/My-Wishlist.csv"),
      "unbuilt"     => Rails.root.join("db/seeds/My-Stash.csv"),
      "in_progress" => Rails.root.join("db/seeds/My-Started.csv"),
      "completed"   => Rails.root.join("db/seeds/My-Completed.csv")
    }

    output_path = Rails.root.join("db/seeds/enriched_kits.json")

    existing = if force
      puts "Force mode — re-enriching all kits..."
      {}
    elsif output_path.exist?
      puts "Loading existing enriched data, skipping already-enriched kits..."
      JSON.parse(output_path.read).index_by { |k| k["scalemates_id"] }
    else
      {}
    end

    all_rows = []
    csv_files.each do |status, path|
      CSV.foreach(path, headers: true) do |row|
        next unless row["Link"].present?
        scalemates_id = row["Link"].match(/--(\d+)$/)&.captures&.first&.to_i
        next unless scalemates_id
        all_rows << { status: status, row: row, scalemates_id: scalemates_id, url: row["Link"] }
      end
    end

    total = all_rows.size
    kits = []

    all_rows.each_with_index do |entry, index|
      counter = "[#{(index + 1).to_s.rjust(total.to_s.length, "0")}/#{total}]"
      status = entry[:status]
      row = entry[:row]
      scalemates_id = entry[:scalemates_id]
      url = entry[:url]

      if existing[scalemates_id]
        puts "#{counter} Skipping #{scalemates_id} (already enriched)"
        kits << existing[scalemates_id]
        next
      end

      puts "#{counter} Scraping #{scalemates_id}: #{row['Title']}..."

      begin
        enriched = scrape_kit(url, row, status, scalemates_id)
        kits << enriched
        sleep 1
      rescue StandardError => e
        puts "  ERROR: #{e.message} — using CSV data only"
        kits << csv_fallback(row, status, scalemates_id, url)
      end
    end

    output_path.write(JSON.pretty_generate(kits))
    puts "\nDone! #{kits.size} kits written to #{output_path}"
  end

  def scrape_kit(url, row, status, scalemates_id)
    user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    stdout, _stderr, status_code = Open3.capture3(
      "curl", "-s", "-L",
      "-A", user_agent,
      "-H", "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "-H", "Accept-Language: en-US,en;q=0.5",
      "--max-time", "15",
      url
    )

    raise "curl failed" unless status_code.success?

    doc = Nokogiri::HTML(stdout)

    image_url  = doc.at('meta[property="og:image"]')&.[]("content")
    full_title = doc.at('meta[property="og:title"]')&.[]("content")
    h1         = doc.at("h1")&.text&.strip
    grade      = parse_grade(h1)

    {
      "scalemates_id"  => scalemates_id,
      "scalemates_url" => url,
      "status"         => status,
      "title"          => row["Title"],
      "scale"          => row["Scale"],
      "brand"          => row["Brand"],
      "topic"          => row["Topic"],
      "full_title"     => full_title,
      "image_url"      => image_url,
      "grade"          => grade,
      "series"         => nil
    }
  end

  def parse_grade(h1)
    return nil unless h1

    grade_patterns = {
      /\AHigh Grade\b/i     => "High Grade",
      /\AReal Grade\b/i     => "Real Grade",
      /\AMaster Grade\b/i   => "Master Grade",
      /\APerfect Grade\b/i  => "Perfect Grade",
      /\ASuper Deformed\b/i => "Super Deformed",
      /\AFull Mechanics\b/i => "Full Mechanics",
      /\AEntry Grade\b/i    => "Entry Grade",
      /\ANo Grade\b/i       => "No Grade"
    }

    grade_patterns.each_with_object(nil) do |(pattern, name), _found|
      break name if h1.match?(pattern)
    end
  end

  def csv_fallback(row, status, scalemates_id, url)
    {
      "scalemates_id"  => scalemates_id,
      "scalemates_url" => url,
      "status"         => status,
      "title"          => row["Title"],
      "scale"          => row["Scale"],
      "brand"          => row["Brand"],
      "topic"          => row["Topic"],
      "full_title"     => nil,
      "image_url"      => nil,
      "grade"          => nil,
      "series"         => nil
    }
  end
end
