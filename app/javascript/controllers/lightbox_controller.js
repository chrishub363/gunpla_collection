import { Controller } from "@hotwired/stimulus"

// Opens a full-screen view of any image clicked with
// `data-action="click->lightbox#open"` and `data-lightbox-src-param="<url>"`.
export default class extends Controller {
  static targets = ["overlay", "image"]

  open(event) {
    const src = event.params.src
    if (!src) return
    this.imageTarget.src = src
    this.overlayTarget.classList.remove("opacity-0", "pointer-events-none")
    document.body.style.overflow = "hidden"
  }

  close() {
    this.overlayTarget.classList.add("opacity-0", "pointer-events-none")
    this.imageTarget.src = ""
    document.body.style.overflow = ""
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
