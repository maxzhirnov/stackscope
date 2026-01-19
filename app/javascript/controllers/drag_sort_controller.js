import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.dragged = null
  }

  start(event) {
    this.dragged = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
    event.currentTarget.classList.add("is-dragging")
  }

  end(event) {
    event.currentTarget.classList.remove("is-dragging")
    this.dragged = null
    this.persistOrder()
  }

  over(event) {
    event.preventDefault()
    const target = event.currentTarget
    if (!this.dragged || this.dragged === target) return

    const list = target.parentNode
    const draggingIndex = [...list.children].indexOf(this.dragged)
    const targetIndex = [...list.children].indexOf(target)
    if (draggingIndex < targetIndex) {
      list.insertBefore(this.dragged, target.nextSibling)
    } else {
      list.insertBefore(this.dragged, target)
    }
  }

  persistOrder() {
    if (!this.urlValue) return
    const ids = [...this.element.querySelectorAll("[data-id]")].map((el) => el.dataset.id)
    const token = document.querySelector("meta[name='csrf-token']")?.content

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token || ""
      },
      body: JSON.stringify({ order: ids })
    })
  }
}
