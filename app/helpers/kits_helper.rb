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

  def scalemates_link(kit)
    return unless kit.scalemates_url.present?
    svg = content_tag(:svg, class: "w-4 h-4", fill: "none", viewBox: "0 0 24 24",
                      stroke: "currentColor", "stroke-width": "1.5") do
      content_tag(:path, "", "stroke-linecap": "round", "stroke-linejoin": "round",
                  d: "M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14")
    end
    link_to svg, kit.scalemates_url, target: "_blank", rel: "noopener noreferrer",
            class: "shrink-0 text-muted hover:text-accent transition-colors p-1 -m-1 rounded"
  end

  def status_badge(status)
    meta = STATUS_META[status]
    return unless meta

    tag.span class: "inline-flex items-center gap-1.5 text-sm font-semibold px-3 py-1.5 rounded-full #{meta[:classes]}" do
      safe_join([ status_icon(meta[:icon]), meta[:label] ])
    end
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
