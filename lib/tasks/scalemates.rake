# Semi-automated ScaleMates stash export.
#
# ScaleMates has no API and the stash-export endpoints require a logged-in
# session (they infer *whose* stash to export from the session cookie alone).
# So we open a real browser, let you log in by hand — which sidesteps CSRF,
# captchas and 2FA — then lift the session cookies out of the browser and reuse
# them with curl to pull the four CSVs. The browser is only ever used for login.

require "selenium-webdriver"
require "open3"

namespace :scalemates do
  # Each owned status maps to one stashexporter.php query. An empty :params is
  # the default stash (unbuilt/owned); the rest are distinguished by &type=.
  EXPORTS = [
    { file: "My-Wishlist.csv",  params: "type=W"  },
    { file: "My-Stash.csv",     params: nil       },
    { file: "My-Started.csv",   params: "type=BB" },
    { file: "My-Completed.csv", params: "type=D"  }
  ].freeze

  EXPORT_BASE = "https://www.scalemates.com/profiles/stashexporter.php?format=csv".freeze

  desc "Open a browser to log into ScaleMates, then download the four stash CSVs into db/seeds/"
  task export: :environment do
    dest = Rails.root.join("db/seeds")

    driver = build_driver
    begin
      driver.navigate.to "https://www.scalemates.com/"

      puts <<~MSG

        A Chromium window has opened on ScaleMates.

          1. Log in (dismiss the cookie banner if it appears).
          2. Wait until you're back on the site, logged in.

      MSG
      print "Then press Enter here to download your exports… "
      $stdin.gets

      cookie_header = driver.manage.all_cookies
        .map { |c| "#{c[:name]}=#{c[:value]}" }
        .join("; ")
      raise "No cookies found in the browser session — did the login complete?" if cookie_header.empty?
    ensure
      driver.quit
    end

    puts "\n== Downloading exports =="
    EXPORTS.each do |export|
      url  = export[:params] ? "#{EXPORT_BASE}&#{export[:params]}" : EXPORT_BASE
      body = fetch_csv(url, cookie_header)

      # A valid export starts with the ScaleMates CSV header. Anything else
      # (a login page, an error) means the session didn't take — leave the
      # committed CSV untouched rather than clobbering it with garbage.
      unless body&.lstrip&.start_with?('"Scale"')
        puts "  ✗ #{export[:file]} — unexpected response, left unchanged (are you logged in?)"
        next
      end

      File.binwrite(dest.join(export[:file]), body)
      puts "  ✓ #{export[:file]} — #{body.lines.count - 1} rows"
    end

    puts "\nDone. Next: bin/rails enrich:kits && bin/rails kit_images:fetch && bin/rails db:seed"
  end

  # Builds a *visible* browser so the user can log in.
  #
  # We deliberately avoid snap Chromium: its bundled "chromedriver" is just a
  # symlink to the snap wrapper, which re-execs the browser out from under
  # WebDriver and reports "Chrome instance exited". So we only use a real,
  # unconfined Chrome if one is installed; otherwise Selenium Manager downloads
  # a matching Chrome for Testing build (one-time, cached in ~/.cache/selenium).
  def build_driver
    options = Selenium::WebDriver::Chrome::Options.new
    if (binary = chrome_binary)
      options.binary = binary
    end
    # Persisted profile under tmp/ so the login can stick between runs.
    options.add_argument("--user-data-dir=#{Rails.root.join('tmp/scalemates-chrome')}")
    options.add_argument("--no-sandbox")
    options.add_argument("--no-first-run")
    options.add_argument("--no-default-browser-check")
    # Look less like an automated browser — ScaleMates sits behind bot protection
    # that flags the usual WebDriver tells. (It still blocks headless; run visible.)
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.exclude_switches = ["enable-automation"]

    Selenium::WebDriver.for(:chrome, options: options)
  end

  # Real, non-snap Chrome only — snap Chromium is intentionally excluded (see
  # build_driver). Returns nil to let Selenium Manager provide the browser.
  def chrome_binary
    %w[
      /usr/bin/google-chrome
      /usr/bin/google-chrome-stable
      /opt/google/chrome/chrome
    ].find { |p| File.executable?(p) }
  end

  # Same curl invocation the other tasks use, plus the captured cookie jar.
  def fetch_csv(url, cookie_header)
    user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    stdout, _stderr, status = Open3.capture3(
      "curl", "-s", "-L", "--max-time", "30",
      "-A", user_agent,
      "-b", cookie_header,
      url
    )

    status.success? ? stdout : nil
  end
end
