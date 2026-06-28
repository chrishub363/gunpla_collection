import { Controller } from "@hotwired/stimulus"

// Remembers whether a <details> filter section is open across the full-page
// reload that a filter change triggers. State lives in the `filter_sections`
// cookie (a comma-separated list of open section keys) so the server can render
// the section open on the next request — no flash of a collapsed section.
export default class extends Controller {
  static values = { key: String }

  static COOKIE = "filter_sections"

  toggle() {
    const keys = new Set(this.readKeys())
    this.element.open ? keys.add(this.keyValue) : keys.delete(this.keyValue)
    this.writeKeys([...keys])
  }

  readKeys() {
    const match = document.cookie.match(new RegExp(`(?:^|;\\s*)${this.constructor.COOKIE}=([^;]*)`))
    return match ? decodeURIComponent(match[1]).split(",").filter(Boolean) : []
  }

  writeKeys(keys) {
    document.cookie = `${this.constructor.COOKIE}=${encodeURIComponent(keys.join(","))}; path=/; max-age=31536000; samesite=lax`
  }
}
