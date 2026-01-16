import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: Number }

  connect() {
    const timeout = this.timeoutValue || 3000
    this.timer = setTimeout(() => {
      this.element.remove()
    }, timeout)
  }

  disconnect() {
    if (this.timer) {
      clearTimeout(this.timer)
    }
  }
}
