# Gunpla Collection

As much as I love ScaleMates its interface can be clunky and doesn't work great on mobile.
My wife needed a simpler list she could use when shopping for gifts and here it is.

This is a small Rails app for browsing and managing a Gunpla (Gundam plastic model) kit
collection — what's owned, built, in progress, and on the wishlist — plus a
"pick a kit" roulette for deciding what to build next. Kit metadata and box-art
images are enriched from [ScaleMates](https://www.scalemates.com).

- **Ruby** 4.0.5 · **Rails** 8.1
- **Database:** SQLite
- **Styling:** Tailwind (via `tailwindcss-rails`), importmap for JS

## Hosting & the rebuild model

The app is hosted on **Render's free tier**, which has an **ephemeral
filesystem** — anything written at runtime is wiped on every deploy and restart.
We lean into that rather than fight it: **nothing is persisted at runtime**. The
SQLite database is treated as a disposable cache that is rebuilt from committed
data on every deploy.

The source of truth is checked into the repo:

- `db/seeds/enriched_kits.json` — the full kit dataset
- `public/kit_images/` — the box-art images, committed as files

On each deploy, [`bin/render-build.sh`](bin/render-build.sh) runs:

```bash
bundle install
bundle exec rails assets:precompile
bundle exec rails db:prepare   # creates the (empty, ephemeral) SQLite db
bundle exec rails db:seed      # rebuilds all kits from enriched_kits.json
```

So `db:seed` is the rebuild: it wipes and recreates the `kits` table from
`enriched_kits.json`. Because the images live under `public/kit_images/` (served
statically with a 1-year cache header) and are referenced by filename, they
survive deploys without any object storage or persistent disk.

## Data pipeline

```
ScaleMates collection exports (CSV)         ← rake scalemates:export (or manual)
        │  rake enrich:kits                  scrape metadata + image source URL
        ▼
db/seeds/enriched_kits.json
        │  rake kit_images:fetch             download photos → public/kit_images/
        ▼
enriched_kits.json (+ image filenames) + committed image files
        │  rake db:seed                      rebuild the database
        ▼
kits table  →  app renders /kit_images/<sha256>.jpg
```

### 1. ScaleMates exports (required input)

The pipeline needs four CSVs in `db/seeds/`, one per status:

| File | Maps to status | Manual download |
|------|----------------|-----------------|
| `My-Wishlist.csv`  | `wishlist` | [link](https://www.scalemates.com/profiles/stashexporter.php?type=W&format=csv) |
| `My-Stash.csv`     | `unbuilt` (owned) | [link](https://www.scalemates.com/profiles/stashexporter.php?format=csv) |
| `My-Started.csv`   | `in_progress` | [link](https://www.scalemates.com/profiles/stashexporter.php?format=csv&type=BB) |
| `My-Completed.csv` | `completed` | [link](https://www.scalemates.com/profiles/stashexporter.php?format=csv&type=D) |

**Automated (recommended):**

```bash
bin/rails scalemates:export
```

ScaleMates has no API, and the export endpoints require a logged-in session, so
this can't be fully headless. The task opens a Chromium window on ScaleMates —
**you log in by hand** (which sidesteps CSRF, captchas and 2FA) and press Enter.
It then lifts your session cookies out of the browser and uses them to download
all four CSVs into `db/seeds/`. The browser is only used for login; the actual
download reuses the same `curl` path as the rest of the pipeline. If a response
doesn't look like a valid export (e.g. the login didn't take), that file is left
unchanged rather than overwritten. The login profile is cached under `tmp/`, so
subsequent runs usually skip straight past the login screen.

Uses an installed Google Chrome if present; otherwise Selenium Manager downloads
a self-contained Chrome for Testing build on first run (one-time, cached under
`~/.cache/selenium`). Snap Chromium is intentionally not used — its bundled
chromedriver doesn't work with WebDriver.

**Manual:** alternatively, download each CSV from the links above (while logged
into ScaleMates) and save it under `db/seeds/` with the filename shown.

The enrichment reads the `Link`, `Title`, `Scale`, `Brand`, and `Topic` columns.
The `Link` column (a ScaleMates product URL ending in `--<id>`) is required — its
trailing id is the ScaleMates id used to scrape each kit.

### 2. Enrich metadata

```bash
bin/rails enrich:kits          # skips kits already in enriched_kits.json
bin/rails enrich:kits[force]   # re-scrape everything from scratch
```

Scrapes each kit's ScaleMates page for `full_title`, `grade`, and the source
image URL, writing results to `db/seeds/enriched_kits.json`.

### 3. Fetch images

```bash
bin/rails kit_images:fetch          # skips images already on disk
bin/rails kit_images:fetch[force]   # re-download everything
```

Downloads the full-resolution box art for each kit, names each file by the
SHA256 of its contents (content-addressed: dedupes identical images and gives
free cache-busting), and writes it to `public/kit_images/`. The filename is
recorded back into `enriched_kits.json` as `image`.

Both `enrich:kits` and `kit_images:fetch` write to `enriched_kits.json` after
every kit (atomic temp-file + rename), so they are **resumable** — if
interrupted, just re-run the same command and it continues where it left off.

### 4. Rebuild the database

```bash
bin/rails db:seed
```

Wipes and rebuilds the `kits` table from `enriched_kits.json`.

> **Typical workflow:** `scalemates:export` (refresh the CSVs) → `enrich:kits` →
> `kit_images:fetch` → `db:seed`. Each step only does the new work; everything
> already done is skipped. **Commit the updated `enriched_kits.json` and any new
> files in `public/kit_images/`** so the next deploy can rebuild from them.

## Local development

```bash
bin/setup        # install dependencies, prepare the database, then start the app
```

`bin/setup` ends by launching `bin/dev` (web server + Tailwind watcher), so a
plain run gets you from a fresh clone to a running app. Then open
http://localhost:3000.

It accepts a few flags:

| Flag | What it does |
|------|--------------|
| `--reset` | Drop, recreate, and reseed the database from `enriched_kits.json` |
| `--refresh` | Run the full pipeline — `scalemates:export` (opens a browser to log in) → `enrich:kits` → `kit_images:fetch` → reseed — refreshing the committed dataset from ScaleMates |
| `--skip-server` | Do the setup work but **don't** launch the app |

Flags compose. `--refresh` only does the *new* scraping/downloading work (it uses
the non-`force` tasks), so it's safe to re-run. Because it ends by launching the
app, pair it with `--skip-server` if you just want to refresh data and keep your
shell:

```bash
bin/setup --refresh --skip-server   # update kit data, no server
```

Don't forget to **commit the updated `enriched_kits.json` and any new
`public/kit_images/` files** afterward so the next deploy rebuilds from them.

To start the server without the setup steps, run `bin/dev` directly.
