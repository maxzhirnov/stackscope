import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]
  static values = { cardId: String }

  start() {
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.add("is-loading")
      this.buttonTarget.setAttribute("aria-busy", "true")
      this.buttonTarget.disabled = true
    }
    const card = this.cardElement()
    if (card) {
      card.classList.add("is-loading")
    }
  }

  stop() {
    if (this.hasButtonTarget) {
      this.buttonTarget.classList.remove("is-loading")
      this.buttonTarget.removeAttribute("aria-busy")
      this.buttonTarget.disabled = false
    }
    const card = this.cardElement()
    if (card) {
      card.classList.remove("is-loading")
    }
  }

  cardElement() {
    if (!this.hasCardIdValue) {
      return null
    }
    return document.getElementById(this.cardIdValue)
  }
}
