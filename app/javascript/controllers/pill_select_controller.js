import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.refresh()
  }

  refresh() {
    this.element.querySelectorAll('input[type="radio"]').forEach(input => {
      const label = this.element.querySelector(`label[for="${input.id}"]`)
      if (!label) return
      const active = input.checked
      // Must mirror pill_filter_label_class in kits_helper.rb.
      label.classList.toggle("bg-accent", active)
      label.classList.toggle("text-on-accent", active)
      label.classList.toggle("bg-elevated", !active)
      label.classList.toggle("text-muted", !active)
      label.classList.toggle("border", !active)
      label.classList.toggle("border-border", !active)
      label.classList.toggle("hover:text-ink", !active)
    })
  }
}
