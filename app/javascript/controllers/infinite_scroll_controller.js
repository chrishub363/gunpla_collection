import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sentinel"]

  connect() {
    this.observer = new IntersectionObserver(
      (entries) => this.handleIntersection(entries),
      { rootMargin: "200px" }
    )
    if (this.hasSentinelTarget) {
      this.observer.observe(this.sentinelTarget)
    }
  }

  disconnect() {
    this.observer.disconnect()
  }

  sentinelTargetConnected(element) {
    if (this.observer) {
      this.observer.observe(element)
    }
  }

  handleIntersection(entries) {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        this.observer.unobserve(entry.target)
        const link = entry.target.querySelector("a")
        if (link) {
          fetch(link.href, {
            headers: { "Accept": "text/vnd.turbo-stream.html" }
          })
          .then(r => r.text())
          .then(html => window.Turbo.renderStreamMessage(html))
        }
      }
    })
  }
}