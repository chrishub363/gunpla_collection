import { Controller } from "@hotwired/stimulus"

// On /pick the filters are chosen client-side (nothing applies until you roll),
// so the picked kit's attribute chips toggle the matching filter radios in place
// instead of navigating. Chips and the pills at the top both reflect the same
// radios, so toggling either keeps both in sync.
export default class extends Controller {
  static targets = ["chip"]

  connect() {
    this.sync = this.sync.bind(this)
    document.addEventListener("change", this.sync)
    this.sync()
  }

  disconnect() {
    document.removeEventListener("change", this.sync)
  }

  toggle(event) {
    const chip = event.currentTarget
    const radio = document.getElementById(chip.dataset.radioId)
    if (!radio) return

    if (radio.checked) {
      const clear = document.getElementById(chip.dataset.clearId)
      if (clear) clear.checked = true
      this.fireChange(clear || radio)
    } else {
      radio.checked = true
      this.fireChange(radio)
    }
  }

  // Dispatch change so pill-select restyles its pills; it also bubbles to the
  // document listener below, which restyles the chips.
  fireChange(el) {
    el.dispatchEvent(new Event("change", { bubbles: true }))
  }

  sync() {
    this.chipTargets.forEach(chip => {
      const radio = document.getElementById(chip.dataset.radioId)
      this.style(chip, Boolean(radio && radio.checked))
    })
  }

  // Must mirror chip_class in kits_helper.rb.
  style(chip, active) {
    chip.classList.toggle("bg-accent", active)
    chip.classList.toggle("text-on-accent", active)
    chip.classList.toggle("hover:bg-accent-hover", active)
    chip.classList.toggle("bg-border", !active)
    chip.classList.toggle("text-muted", !active)
    chip.classList.toggle("hover:text-ink", !active)
    chip.setAttribute("aria-pressed", active)
  }
}
