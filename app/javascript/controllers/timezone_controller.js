import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { current: String }

  connect() {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!tz) return

    const stored = localStorage.getItem("stackscope_timezone")
    if (stored === tz && this.currentValue === tz) return

    this.postTimezone(tz)
  }

  postTimezone(tz) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    fetch("/timezone", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token || ""
      },
      body: JSON.stringify({ timezone: tz })
    }).then(() => {
      localStorage.setItem("stackscope_timezone", tz)
    })
  }
}
