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
ScaleMates collection exports (CSV)         ← you export these from ScaleMates
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

Export your collection from ScaleMates as CSV and place the files here, one per
status:

| File | Maps to status |
|------|----------------|
| `db/seeds/[My-Wishlist.csv](https://www.scalemates.com/profiles/stashexporter.php?type=W&format=csv)`  | `wishlist` |
| `db/seeds/[My-Stash.csv](https://www.scalemates.com/profiles/stashexporter.php?format=csv)`     | `unbuilt` (owned) |
| `db/seeds/[My-Started.csv](https://www.scalemates.com/profiles/stashexporter.php?format=csv&type=BB)`   | `in_progress` |
| `db/seeds/[My-Completed.csv](https://www.scalemates.com/profiles/stashexporter.php?format=csv&type=D)` | `completed` |

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

> **Typical workflow:** add kits to the CSVs → `enrich:kits` → `kit_images:fetch`
> → `db:seed`. Each step only does the new work; everything already done is
> skipped. **Commit the updated `enriched_kits.json` and any new files in
> `public/kit_images/`** so the next deploy can rebuild from them.

## Local development

```bash
bin/setup        # install dependencies, prepare the database
bin/dev          # start the web server + Tailwind watcher
```

Then open http://localhost:3000.
