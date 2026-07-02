require "csv"
require "json"
require "open3"
require "nokogiri"

namespace :enrich do
  desc "Scrape ScaleMates and store the raw page data (h1, subtitle, spec table, image) for all kits — no interpretation; processing happens at seed. Use enrich:kits[force] to re-enrich everything."
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

    # Per-product scraped data (image_url, h1, subtitle, specs) is identical for
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
          product = scrape_kit(url, scalemates_id)
        rescue StandardError => e
          puts "  ERROR: #{e.message} — using CSV data only"
          product = csv_fallback(scalemates_id, url)
        end
        scraped[scalemates_id] = product
        sleep 1
      end

      # Combine the shared raw page data with this copy's own status/CSV fields.
      # The CSV columns are the authoritative per-copy values; the page `specs`
      # carry their own Brand/Scale/Topic, but those are reference-only and left
      # untouched for seed to reconcile.
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

  # Fetches the ScaleMates kit page and lifts the raw fields verbatim — no
  # grade parsing, no availability classification, no normalization. That all
  # happens at seed time against this stored data, so the classification logic
  # can be refined later without re-scraping. Returned hash is the per-product
  # data shared across every owned copy of this kit (see the cache in the task).
  def scrape_kit(url, scalemates_id)
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

    {
      "scalemates_id"  => scalemates_id,
      "scalemates_url" => url,
      "og_title"       => doc.at('meta[property="og:title"]')&.[]("content"),
      "image_url"      => doc.at('meta[property="og:image"]')&.[]("content"),
      # h1 carries the grade prefix + kit name (e.g. "Real Grade RX-0 …"); seed
      # parses the grade out of it. subtitle is the marketing line under the
      # title (the Title row's `.ut` span), which is where ScaleMates puts the
      # distribution label — "(Premium Bandai Limited)", "(The Gundam Base
      # Limited)", etc. — that seed classifies into an availability.
      "h1"             => doc.at("h1")&.text&.strip,
      "subtitle"       => extract_subtitle(doc),
      # The full detail table, lifted generically as label => value. Kits list
      # different rows (Barcode/Topic/Packaging/…), so we capture whatever is
      # present rather than cherry-picking known keys.
      "specs"          => extract_specs(doc)
    }
  end

  # Every spec row is a `<dt class="p4 bgl">Label:` followed by its `<dd>` value
  # sibling. Captured raw — annotations glued onto values (e.g. "2019New parts",
  # "5059130 (Also listed as …)") are left for seed to clean.
  def extract_specs(doc)
    doc.css("dt.bgl").each_with_object({}) do |dt, specs|
      label = dt.text.strip.chomp(":")
      dd = dt.xpath("following-sibling::dd[1]").first
      specs[label] = dd&.text&.strip&.gsub(/\s+/, " ") if label.present?
    end
  end

  # The marketing subtitle lives in the `.ut` span inside the Title spec row.
  # Scoped to that row so it can't pick up the many other `.ut` spans on the page
  # (related-kit blurbs, section labels, …).
  def extract_subtitle(doc)
    title_dd = doc.css("dt.bgl")
      .find { |dt| dt.text.strip.chomp(":") == "Title" }
      &.xpath("following-sibling::dd[1]")&.first
    title_dd&.at_css("span.ut")&.text&.strip
  end

  # A kit counts as fully enriched only once the scrape produced a title heading
  # and a usable box-art source. Kits scraped before ScaleMates uploaded artwork
  # get a placeholder image_url (".../products/img/" with no file), so re-running
  # enrich:kits retries them instead of skipping them forever.
  def enriched_complete?(kit)
    kit["h1"].present? && valid_image_url?(kit["image_url"])
  end

  def valid_image_url?(url)
    return false if url.blank?

    url.split("?").first.match?(/\.(jpe?g|png|webp)\z/i)
  end

  # When a scrape fails outright we still emit a row (keyed to its ids) so seed
  # has the CSV-derived fields; the raw page fields are simply absent.
  def csv_fallback(scalemates_id, url)
    {
      "scalemates_id"  => scalemates_id,
      "scalemates_url" => url,
      "og_title"       => nil,
      "image_url"      => nil,
      "h1"             => nil,
      "subtitle"       => nil,
      "specs"          => {}
    }
  end
end
