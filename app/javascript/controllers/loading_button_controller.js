import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  start() {
    if (!this.hasButtonTarget) {
      return
    }
    this.buttonTarget.classList.add("is-loading")
    this.buttonTarget.setAttribute("aria-busy", "true")
    this.buttonTarget.disabled = true
  }

  stop() {
    if (!this.hasButtonTarget) {
      return
    }
    this.buttonTarget.classList.remove("is-loading")
    this.buttonTarget.removeAttribute("aria-busy")
    this.buttonTarget.disabled = false
  }
}
