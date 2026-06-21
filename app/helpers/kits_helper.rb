module KitsHelper
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
    case status
    when "completed"
      tag.span "✓ Built",    class: "text-xs font-medium px-2 py-1 rounded-full bg-built-bg text-built-fg"
    when "in_progress"
      tag.span "⚙ Building", class: "text-xs font-medium px-2 py-1 rounded-full bg-building-bg text-building-fg"
    when "unbuilt"
      tag.span "Unbuilt",    class: "text-xs font-medium px-2 py-1 rounded-full bg-border text-muted"
    when "wishlist"
      tag.span "Wishlist",   class: "text-xs font-medium px-2 py-1 rounded-full bg-wishlist-bg text-wishlist-fg"
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
end
