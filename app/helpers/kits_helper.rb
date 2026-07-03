module KitsHelper
  # Single source of truth for how each status appears to users — keeps the
  # badge and the sidebar filter labels in sync. The stored value stays e.g.
  # "unbuilt"; only the displayed label/icon changes here.
  STATUS_META = {
    "completed"   => { label: "Built",    icon: :check, classes: "bg-built-bg text-built-fg" },
    "in_progress" => { label: "Building", icon: :gear,  classes: "bg-building-bg text-building-fg" },
    "unbuilt"     => { label: "Owned",    icon: :box,   classes: "bg-border text-muted" },
    "wishlist"    => { label: "Wishlist", icon: :gift,  classes: "bg-wishlist-bg text-wishlist-fg" }
  }.freeze

  def status_label(status)
    STATUS_META.dig(status, :label) || status.humanize
  end

  # Shown for kits with no valid box art (e.g. kits scraped before ScaleMates
  # uploaded artwork). Content-addressed like every other image under
  # public/kit_images; update this if the placeholder is ever regenerated.
  PLACEHOLDER_IMAGE = "719b37dd4bbeefa25a17940dd7a1726d289890669755e8775fc1a00c7503ee15.jpg".freeze

  # Public path to a kit's locally-committed box art, falling back to the
  # placeholder silhouette when the kit has none.
  def kit_image_path(kit)
    "/kit_images/#{kit.image.presence || PLACEHOLDER_IMAGE}"
  end

  # The strip of outgoing "source" links under a kit: ScaleMates (the real
  # scraped deep link) plus search links to the Gunpla wiki, a store, and eBay.
  # Rendered as brand-coloured monogram tiles grouped in a pill so they read as
  # "leave the site" links, distinct from the on-site filter chips above them.
  def kit_source_links(kit)
    tag.div class: "link-tiles mt-2" do
      safe_join(kit_source_link_defs(kit).map { |l|
        link_to l[:label], l[:url], target: "_blank", rel: "noopener noreferrer",
                class: "link-tile #{l[:tile]}", title: l[:title]
      })
    end
  end

  # Ordered link descriptors for a kit. ScaleMates is a stored deep link (dropped
  # if absent); the rest are search links built from the kit's grade + title. The
  # store slot follows availability: retail → USA Gundam Store, limited → P-Bandai
  # (which carries most exclusives retail never stocks). See [[external-links-expansion]].
  def kit_source_link_defs(kit)
    q = ERB::Util.url_encode([ kit.grade_abbr, kit.title ].compact.join(" "))

    defs = []
    if kit.scalemates_url.present?
      defs << { label: "SM", tile: "link-tile-sm", title: "View on ScaleMates", url: kit.scalemates_url }
    end
    defs << { label: "GW", tile: "link-tile-gw", title: "Search the Gunpla wiki",
              url: "https://gunpla.fandom.com/wiki/Special:Search?query=#{q}&scope=internal" }
    if kit.availability == "limited"
      defs << { label: "PB", tile: "link-tile-pb", title: "Search P-Bandai (Bandai Hobby Online Shop)",
                url: pbandai_search_url(q) }
    else
      defs << { label: "UG", tile: "link-tile-ug", title: "Search USA Gundam Store",
                url: "https://www.usagundamstore.com/search?q=#{q}" }
    end
    defs << { label: "eB", tile: "link-tile-eb", title: "Search eBay",
              url: "https://www.ebay.com/sch/i.html?_nkw=#{q}" }
    defs
  end

  # Scoped to the Bandai Hobby Online Shop (_f_shops=05-0002) and set to include
  # ended / no-longer-available items (_f_productStatuses=Waiting,On,End) so
  # sold-out exclusives still surface. Param shape mirrors p-bandai.com's own
  # search URLs; the comma in productStatuses is pre-encoded (%2C).
  def pbandai_search_url(encoded_query)
    "https://p-bandai.com/us/search?keyword=#{encoded_query}" \
      "&offset=0&limit=20&sortType=Relevance" \
      "&_f_productStatuses=Waiting%2COn%2CEnd&_f_shops=05-0002"
  end

  # The status pill. In the collection grid it doubles as a filter toggle
  # (link: true) — clicking filters the collection by that status and breaks out
  # of the kits_grid frame so grid + sidebar re-render in sync, exactly like the
  # attribute chips. It keeps its semantic status color and gets an accent ring
  # when its filter is active. Wishlist kits (and the wishlist tab, which has no
  # status facet) always render a plain, non-clickable pill.
  def status_badge(status, link: false)
    meta = STATUS_META[status]
    return unless meta

    content = safe_join([ status_icon(meta[:icon]), meta[:label] ])
    base = "inline-flex items-center gap-1.5 text-sm font-semibold px-3 py-1.5 rounded-full #{meta[:classes]}"

    return tag.span(content, class: base) unless link && status_filterable?(status)

    active = params[:status].to_s == status
    ring = active ? "ring-2 ring-accent" : "hover:ring-2 hover:ring-muted"

    link_to content, filtered_kits_path(status: active ? nil : status),
            "aria-pressed": active,
            title: active ? "Remove #{meta[:label]} filter" : "Filter by #{meta[:label]}",
            class: "#{base} transition-shadow #{ring}",
            data: { turbo_action: "advance", turbo_frame: "_top" }
  end

  # Status filtering only applies to the collection tab — the wishlist tab has no
  # status facet, and every wishlist kit shares the "wishlist" status.
  def status_filterable?(status)
    status != "wishlist" && @tab != "wishlist"
  end

  CHIP_BASE_CLASS = "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium transition-colors".freeze

  # The attribute chips under a kit's title (brand, scale, grade). Each chip is a
  # toggle filter kept in sync with the sidebar: both derive their active state
  # from the same query params, so selecting a filter in either place lights up
  # the other. Clicking an active chip clears that facet. Blank attributes drop.
  # scope: :collection renders chips as filter links (sidebar-synced navigation);
  # :pick renders them as buttons that toggle the picker's filter radios in place
  # (no navigation), staying in sync with the pills at the top of /pick.
  def kit_attribute_tags(kit, scope: :collection)
    chips = kit_attribute_chips(kit)
    return if chips.empty?

    div_data = scope == :pick ? { controller: "pick-chips" } : {}

    tag.div class: "flex flex-wrap gap-1.5 mt-1", data: div_data do
      safe_join(chips.map { |chip| kit_attribute_tag(chip, scope) })
    end
  end

  # Chip descriptors: a label plus the facet (param key + value) it filters on.
  # Grade displays its full name but filters by grade_abbr (what the controller
  # and sidebar match on); a grade with no abbr has no key and renders plain.
  def kit_attribute_chips(kit)
    chips = []
    chips << { label: kit.brand, key: :brand, value: kit.brand } if kit.brand.present?
    chips << { label: scale_label(kit.scale), key: :scale, value: kit.scale } if kit.scale.present?
    if kit.grade.present?
      chips << { label: kit.grade, key: (:grade if kit.grade_abbr.present?), value: kit.grade_abbr }
    end
    chips << { label: kit.availability.capitalize, key: :availability, value: kit.availability } if kit.availability.present?
    chips
  end

  def kit_attribute_tag(chip, scope)
    return tag.span(chip[:label], class: "#{CHIP_BASE_CLASS} bg-border text-muted") if chip[:key].blank?

    active = params[chip[:key]].to_s == chip[:value].to_s
    return pick_chip_button(chip, active) if scope == :pick

    target = filtered_kits_path(chip[:key] => (active ? nil : chip[:value]))

    # Break out of the kits_grid frame so a chip click re-renders the whole page
    # (grid + sidebar) and updates the URL — keeping both filter surfaces in sync.
    link_to chip[:label], target, "aria-pressed": active,
            title: active ? "Remove #{chip[:label]} filter" : "Filter by #{chip[:label]}",
            class: chip_class(active),
            data: { turbo_action: "advance", turbo_frame: "_top" }
  end

  # A /pick chip: a button wired to the matching filter radio (and its "All"
  # radio for toggling off). The pick-chips controller flips the radio and keeps
  # the chip's styling in sync with the pills. ids mirror those in pick.html.erb.
  def pick_chip_button(chip, active)
    tag.button chip[:label], type: "button", "aria-pressed": active,
               title: active ? "Remove #{chip[:label]} filter" : "Filter by #{chip[:label]}",
               class: "#{chip_class(active)} cursor-pointer",
               data: {
                 pick_chips_target: "chip",
                 action: "click->pick-chips#toggle",
                 radio_id: pick_radio_id(chip[:key], chip[:value]),
                 clear_id: "pick_#{chip[:key]}_all"
               }
  end

  def pick_radio_id(key, value)
    suffix =
      case key
      when :scale then value.gsub(":", "_")
      when :brand then value.parameterize
      else value # grade is already the abbr
      end
    "pick_#{key}_#{suffix}"
  end

  def chip_class(active)
    if active
      "#{CHIP_BASE_CLASS} bg-accent text-on-accent hover:bg-accent-hover"
    else
      "#{CHIP_BASE_CLASS} bg-border text-muted hover:text-ink"
    end
  end

  # Current tab + filters, with the given facet override merged in (a nil value
  # removes that facet). Drops pagination/search/roll so the link lands clean.
  def filtered_kits_path(override)
    preserved = params.permit(:tab, :status, :grade, :scale, :brand, :availability).to_h
    root_path(preserved.merge(override.stringify_keys))
  end

  # ScaleMates exports scale-less kits with the literal scale "No"; show that as
  # the clearer "No Scale". Returns nil for a genuinely blank scale.
  def scale_label(scale)
    return if scale.blank?
    scale == "No" ? "No Scale" : scale
  end

  # Whether a sidebar filter section should render expanded, remembered per
  # section in the `filter_sections` cookie (written client-side by the
  # filter-section Stimulus controller). Keeps sections as the user left them
  # across the reload a filter change triggers.
  def filter_section_open?(title)
    cookies[:filter_sections].to_s.split(",").include?(title)
  end

  def sidebar_filter_label_class(active)
    base = "block px-3 py-1.5 rounded cursor-pointer text-sm transition-colors"
    active ? "#{base} bg-accent text-on-accent" : "#{base} text-muted hover:text-ink hover:bg-elevated"
  end

  def pill_filter_label_class(active)
    base = "cursor-pointer px-3 py-1 rounded-full text-sm font-medium transition-colors"
    active ? "#{base} bg-accent text-on-accent" : "#{base} bg-elevated text-muted border border-border hover:text-ink"
  end

  private

  # Outline icons that inherit the badge's text color via currentColor.
  def status_icon(name)
    paths =
      case name
      when :check
        tag.path(d: "M20 6 9 17l-5-5")
      when :gear
        safe_join([
          tag.path(d: "M10.34 3.94c.09-.54.56-.94 1.1-.94h1.1c.55 0 1.02.4 1.11.94l.17 1.02c.05.32.28.58.59.69.23.08.46.18.68.29.29.15.64.13.91-.05l.85-.56c.45-.3 1.05-.24 1.43.15l.78.78c.39.38.45.98.15 1.43l-.56.85c-.18.27-.2.62-.05.91.11.22.21.45.29.68.11.31.37.54.69.59l1.02.17c.54.09.94.56.94 1.1v1.1c0 .55-.4 1.02-.94 1.11l-1.02.17c-.32.05-.58.28-.69.59-.08.23-.18.46-.29.68-.15.29-.13.64.05.91l.56.85c.3.45.24 1.05-.15 1.43l-.78.78c-.38.39-.98.45-1.43.15l-.85-.56c-.27-.18-.62-.2-.91-.05-.22.11-.45.21-.68.29-.31.11-.54.37-.59.69l-.17 1.02c-.09.54-.56.94-1.11.94h-1.1c-.54 0-1.01-.4-1.1-.94l-.17-1.02c-.05-.32-.28-.58-.59-.69-.23-.08-.46-.18-.68-.29-.29-.15-.64-.13-.91.05l-.85.56c-.45.3-1.05.24-1.43-.15l-.78-.78c-.39-.38-.45-.98-.15-1.43l.56-.85c.18-.27.2-.62.05-.91-.11-.22-.21-.45-.29-.68-.11-.31-.37-.54-.69-.59l-1.02-.17c-.54-.09-.94-.56-.94-1.11v-1.1c0-.54.4-1.01.94-1.1l1.02-.17c.32-.05.58-.28.69-.59.08-.23.18-.46.29-.68.15-.29.13-.64-.05-.91l-.56-.85c-.3-.45-.24-1.05.15-1.43l.78-.78c.38-.39.98-.45 1.43-.15l.85.56c.27.18.62.2.91.05.22-.11.45-.21.68-.29.31-.11.54-.37.59-.69l.17-1.02Z"),
          tag.circle(cx: 12, cy: 12, r: 2.6)
        ])
      when :box
        tag.path(d: "m21 7.5-9-5.25L3 7.5m18 0-9 5.25m9-5.25v9l-9 5.25M3 7.5l9 5.25M3 7.5v9l9 5.25m0-9v9")
      when :gift
        tag.path(d: "M21 11.25v8.25a1.5 1.5 0 0 1-1.5 1.5H4.5a1.5 1.5 0 0 1-1.5-1.5v-8.25M12 4.875A2.625 2.625 0 1 0 9.375 7.5H12m0-2.625V7.5m0-2.625A2.625 2.625 0 1 1 14.625 7.5H12m0 0V21m-9-9.75h18c.41 0 .75-.34.75-.75v-1.5c0-.41-.34-.75-.75-.75H3c-.41 0-.75.34-.75.75v1.5c0 .41.34.75.75.75Z")
      end

    content_tag(:svg, paths, class: "w-4 h-4 shrink-0", fill: "none", stroke: "currentColor",
                "stroke-width": "1.8", "stroke-linecap": "round", "stroke-linejoin": "round",
                viewBox: "0 0 24 24", "aria-hidden": "true")
  end
end
