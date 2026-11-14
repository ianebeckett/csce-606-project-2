// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

// Ctrl+Enter (Cmd+Enter on macOS) submits a textarea that opts in with
// data-submit-on-ctrl-enter. Its form's button still works without JavaScript.
document.addEventListener("keydown", (event) => {
  const field = event.target
  if (event.key !== "Enter" || !(event.ctrlKey || event.metaKey)) return
  if (!(field instanceof HTMLTextAreaElement) || !field.hasAttribute("data-submit-on-ctrl-enter")) return

  event.preventDefault()
  field.form?.requestSubmit()
})


// Automatically open the practice rating modal

const openPracticeRatingModal = () => {
  const modal = document.getElementById("practice-rating-modal")

  if (!modal) return

  // Prevent closing the modal with Esc
  if (!modal.dataset.dismissLocked) {
    modal.addEventListener("cancel", (event) => {
      event.preventDefault()
    })

    modal.dataset.dismissLocked = "true"
  }

  if (!modal.open) {
    modal.showModal()
  }
}


document.addEventListener("turbo:load", openPracticeRatingModal)
document.addEventListener("DOMContentLoaded", openPracticeRatingModal)


// AI chat: keep the newest message in view, and show that the AI is
// thinking while the page waits for its reply. The form still posts
// normally, so everything works without JavaScript.
const scrollChatToEnd = () => {
  document.querySelectorAll("[data-chat-log]").forEach((log) => {
    log.scrollTop = log.scrollHeight
  })
}

const chatMessage = (role, author, text) => {
  const item = document.createElement("li")
  item.className = `conversation-message ${role}`
  const name = document.createElement("strong")
  name.textContent = author
  const body = document.createElement("p")
  body.textContent = text
  item.append(name, body)
  return item
}

document.addEventListener("submit", (event) => {
  const form = event.target
  if (!(form instanceof HTMLFormElement) || !form.hasAttribute("data-chat-form")) return

  const log = form.closest(".coach-body")?.querySelector("[data-chat-log]")
  const field = form.querySelector("textarea")
  const button = form.querySelector("[type=submit]")
  if (log && field?.value.trim()) {
    log.append(chatMessage("user", "You", field.value.trim()))
    const thinking = chatMessage("assistant thinking", form.dataset.chatThinking || "Thinking", "")
    thinking.setAttribute("role", "status")
    thinking.querySelector("p").innerHTML = '<span class="thinking-dots" aria-hidden="true"><span></span><span></span><span></span></span><span class="sr-only">Waiting for a reply</span>'
    log.append(thinking)
    log.scrollTop = log.scrollHeight
  }

  // Wait a tick so the browser has already built the form data.
  setTimeout(() => {
    field?.setAttribute("readonly", "")
    if (button) {
      button.disabled = true
      button.value = "Thinking…"
    }
  })
})

// The Back button can restore a chat page mid-request, with the form still
// disabled. Reload it so the conversation and form are current.
window.addEventListener("pageshow", (event) => {
  if (event.persisted && document.querySelector("[data-chat-form] [type=submit]:disabled")) window.location.reload()
})


// Toasts close on their button and fade out on their own after a while.
const setUpToasts = () => {
  document.querySelectorAll("[data-toast]").forEach((toast) => {
    const close = () => toast.remove()
    toast.querySelector("[data-toast-close]")?.addEventListener("click", close)
    setTimeout(() => {
      if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) close()
      else toast.classList.add("toast-leaving")
    }, 8000)
    toast.addEventListener("animationend", (event) => {
      if (event.animationName === "toast-out") close()
    })
  })
}

const setUpChatPage = () => {
  scrollChatToEnd()
  setUpToasts()
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", setUpChatPage)
} else {
  setUpChatPage()
}
