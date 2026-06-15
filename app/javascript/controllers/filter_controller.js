import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "row", "clearBtn"]

  filter() {
    const query = this.inputTarget.value.toLowerCase().trim()

    if (this.hasClearBtnTarget) {
      this.clearBtnTarget.classList.toggle("hidden", query === "")
    }

    this.rowTargets.forEach((row) => {
      const text = row.dataset.filterText || ""
      row.style.display = query === "" || text.includes(query) ? "" : "none"
    })
  }

  clear() {
    this.inputTarget.value = ""
    this.filter()
    this.inputTarget.focus()
  }

  // Called by Stimulus whenever a row target is added to the DOM (turbo frame swap or stream append)
  rowTargetConnected(element) {
    if (!this.hasInputTarget) return
    const query = this.inputTarget.value.toLowerCase().trim()
    const text = element.dataset.filterText || ""
    element.style.display = query === "" || text.includes(query) ? "" : "none"
  }
}