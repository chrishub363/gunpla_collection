import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "row"]

  filter() {
    const query = this.inputTarget.value.toLowerCase().trim()

    this.rowTargets.forEach((row) => {
      const text = row.dataset.filterText || ""
      row.style.display = query === "" || text.includes(query) ? "" : "none"
    })
  }

  // Called by Stimulus whenever a row target is added to the DOM (turbo frame swap or stream append)
  rowTargetConnected(element) {
    if (!this.hasInputTarget) return
    const query = this.inputTarget.value.toLowerCase().trim()
    const text = element.dataset.filterText || ""
    element.style.display = query === "" || text.includes(query) ? "" : "none"
  }
}