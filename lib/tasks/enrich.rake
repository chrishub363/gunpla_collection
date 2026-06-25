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

    # Persist after every scrape via temp-file + atomic rename, so the JSON on
    # disk is always a complete snapshot and an interruption never loses progress.
    # On re-run, already-enriched kits are skipped, making this fully resumable.
    write_json = lambda do |data|
      tmp = "#{output_path}.tmp"
      File.write(tmp, JSON.pretty_generate(data))
      File.rename(tmp, output_path)
    end

    # Per-product scraped data (image_url, full_title, grade) is identical for
    # every owned copy of a kit, so cache it by scalemates_id and scrape each id
    # at most once. Status and the other CSV columns are per-copy and always come
    # from the current row — this is what keeps two copies of the same kit (e.g.
    # one built, one not) from collapsing onto a single status.
    scraped = {}
    existing.each_value do |kit|
      scraped[kit["scalemates_id"]] = kit if enriched_complete?(kit)
    end

    all_rows.each_with_index do |entry, index|
      counter = "[#{(index + 1).to_s.rjust(total.to_s.length, "0")}/#{total}]"
      status = entry[:status]
      row = entry[:row]
      scalemates_id = entry[:scalemates_id]
      url = entry[:url]

      product = scraped[scalemates_id]
      if product
        puts "#{counter} Reusing #{scalemates_id} (#{row['Title']})"
      else
        puts "#{counter} Scraping #{scalemates_id}: #{row['Title']}..."
        begin
          product = scrape_kit(url, row, status, scalemates_id)
        rescue StandardError => e
          puts "  ERROR: #{e.message} — using CSV data only"
          product = csv_fallback(row, status, scalemates_id, url)
        end
        scraped[scalemates_id] = product
        sleep 1
      end

      # Combine the shared product data with this copy's own status/CSV fields.
      kits << product.merge(
        "status"         => status,
        "title"          => row["Title"],
        "scale"          => row["Scale"],
        "brand"          => row["Brand"],
        "topic"          => row["Topic"],
        "scalemates_id"  => scalemates_id,
        "scalemates_url" => url
      )
      write_json.call(kits)
    end

    write_json.call(kits)
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

  # A kit counts as fully enriched only if the scrape produced a title and a
  # usable box-art source. Kits scraped before ScaleMates uploaded artwork get a
  # placeholder image_url (".../products/img/" with no file), so re-running
  # enrich:kits retries them instead of skipping them forever.
  def enriched_complete?(kit)
    kit["full_title"].present? && valid_image_url?(kit["image_url"])
  end

  def valid_image_url?(url)
    return false if url.blank?

    url.split("?").first.match?(/\.(jpe?g|png|webp)\z/i)
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
