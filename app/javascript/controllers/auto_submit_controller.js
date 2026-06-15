import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "clearBtn"]

  submit() {
    this.element.requestSubmit()
  }

  submitWithDelay() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 400)
  }

  toggleClear() {
    if (this.hasClearBtnTarget && this.hasSearchInputTarget) {
      this.clearBtnTarget.classList.toggle("hidden", this.searchInputTarget.value === "")
    }
  }

  clearAndSubmit() {
    if (this.hasSearchInputTarget) this.searchInputTarget.value = ""
    if (this.hasClearBtnTarget) this.clearBtnTarget.classList.add("hidden")
    this.element.requestSubmit()
  }
}
