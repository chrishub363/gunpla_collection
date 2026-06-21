import { Controller } from "@hotwired/stimulus"

// Flips between the "light" (RX-78-2) and "dark" (Titans) themes by toggling a
// class on <html>, and remembers the explicit choice in localStorage. The initial
// theme is applied before first paint by the inline script in the layout head;
// this controller only handles the user-initiated switch.
export default class extends Controller {
  toggle() {
    const root = document.documentElement
    const next = root.classList.contains("light") ? "dark" : "light"
    root.classList.remove("light", "dark")
    root.classList.add(next)
    try {
      localStorage.setItem("theme", next)
    } catch (e) {
      // Private mode / storage disabled — theme still applies for this session.
    }

    const favicon = document.getElementById("favicon")
    if (favicon) favicon.href = next === "light" ? "/icon-rx78.svg" : "/icon-titans.svg"
  }
}
