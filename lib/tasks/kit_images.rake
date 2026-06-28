require "json"
require "digest"
require "open3"
require "fileutils"
require "set"

namespace :kit_images do
  desc "Download box-art images referenced in enriched_kits.json into public/kit_images, content-addressed by SHA256. Use kit_images:fetch[force] to re-download everything."
  task :fetch, [ :mode ] => :environment do |_task, args|
    $stdout.sync = true
    force = args[:mode] == "force"

    json_path = Rails.root.join("db/seeds/enriched_kits.json")
    dest_dir  = Rails.root.join("public/kit_images")
    FileUtils.mkdir_p(dest_dir)

    kits = JSON.parse(json_path.read)
    total = kits.size
    downloaded = skipped = failed = missing = 0

    # Persist after every change via temp-file + atomic rename, so the JSON on
    # disk is always a complete snapshot and an interruption never loses progress.
    write_json = lambda do |data|
      tmp = "#{json_path}.tmp"
      File.write(tmp, JSON.pretty_generate(data))
      File.rename(tmp, json_path)
    end

    kits.each_with_index do |kit, index|
      counter = "[#{(index + 1).to_s.rjust(total.to_s.length, '0')}/#{total}]"

      source = kit["image_url"]
      if source.blank?
        missing += 1
        puts "#{counter} #{kit['title']} — no source image"
        next
      end

      if !force && kit["image"].present? && dest_dir.join(kit["image"]).exist?
        skipped += 1
        next
      end

      # Strip the scalemates social-card policy (?impolicy=og-image&label=...) to
      # get the full-resolution product photo without letterboxing or branding.
      raw_url = source.split("?").first

      filename = download_image(raw_url, dest_dir)
      if filename
        kit["image"] = filename
        write_json.call(kits)
        downloaded += 1
        puts "#{counter} #{kit['title']} — #{filename}"
        sleep 0.5
      else
        failed += 1
        puts "#{counter} #{kit['title']} — FAILED (#{raw_url})"
      end
    end

    write_json.call(kits)
    puts "\nDone. #{downloaded} downloaded, #{skipped} already present, " \
         "#{missing} no source, #{failed} failed — #{total} total."
  end

  desc "Delete images in public/kit_images not referenced by enriched_kits.json (orphans left behind when a re-scrape returns slightly different bytes). Use kit_images:prune[dry] to preview without deleting."
  task :prune, [ :mode ] => :environment do |_task, args|
    $stdout.sync = true
    dry = args[:mode] == "dry"

    dir = Rails.root.join("public/kit_images")

    referenced = JSON.parse(Rails.root.join("db/seeds/enriched_kits.json").read)
      .map { |k| k["image"] }.compact.reject(&:empty?).to_set
    referenced << KitsHelper::PLACEHOLDER_IMAGE # never prune the fallback silhouette

    orphans = Dir.children(dir).select { |name| File.file?(dir.join(name)) && !referenced.include?(name) }

    if orphans.empty?
      puts "Nothing to prune — every image on disk is referenced."
      next
    end

    mb = (orphans.sum { |name| File.size(dir.join(name)) } / 1024.0 / 1024).round(1)
    puts "#{orphans.size} orphaned image(s), #{mb} MB#{dry ? ' (dry run)' : ''}:"
    orphans.first(8).each { |name| puts "  #{name}" }
    puts "  … and #{orphans.size - 8} more" if orphans.size > 8

    if dry
      puts "\nDry run — nothing deleted. Re-run as `kit_images:prune` to delete."
    else
      orphans.each { |name| File.delete(dir.join(name)) }
      puts "\nDeleted #{orphans.size} orphaned image(s)."
    end
  end

  # Downloads url, names the file by the SHA256 of its bytes, writes it to
  # dest_dir (deduping identical images for free), and returns the filename.
  def download_image(url, dest_dir)
    user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    stdout, _stderr, status = Open3.capture3(
      "curl", "-s", "-L", "--max-time", "20", "-A", user_agent, url
    )

    body = stdout.b
    return nil unless status.success? && body.bytesize > 1024

    filename = "#{Digest::SHA256.hexdigest(body)}.jpg"
    path = dest_dir.join(filename)
    File.binwrite(path, body) unless path.exist?
    filename
  end
end
