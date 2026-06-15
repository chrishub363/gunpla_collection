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
      label.classList.toggle("bg-[#e879a0]", active)
      label.classList.toggle("text-white", active)
      label.classList.toggle("bg-[#251f33]", !active)
      label.classList.toggle("text-[#9d8faa]", !active)
      label.classList.toggle("border", !active)
      label.classList.toggle("border-[#2d2640]", !active)
    })
  }
}
