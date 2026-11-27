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
    // The message now shows in the chat, so empty the box. The browser has
    // already captured its text for the request.
    if (field) field.value = ""
    field?.setAttribute("readonly", "")
    if (button) {
      button.disabled = true
      button.value = "Thinking..."
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

// Submission page: while the verdict is Pending, poll for it and reload
// the page when it arrives, so the member doesn't have to refresh. The
// Refresh result link still works without JavaScript.
const JUDGED_KEY = "code-coach:just-judged"
const POLL_START_MS = 1500
const POLL_MAX_MS = 10000
const POLL_GIVE_UP_MS = 15 * 60 * 1000

const remember = (key, value) => {
  try { value === null ? sessionStorage.removeItem(key) : sessionStorage.setItem(key, value) } catch {}
}
const recall = (key) => {
  try { return sessionStorage.getItem(key) } catch { return null }
}

const watchPendingResult = () => {
  const card = document.querySelector("[data-attempt-status-url]")
  if (!card) return

  card.querySelector("[data-live-result-hint]")?.removeAttribute("hidden")
  const startedAt = Date.now()
  let delay = POLL_START_MS

  const poll = async () => {
    try {
      const response = await fetch(card.dataset.attemptStatusUrl, { headers: { Accept: "application/json" }, cache: "no-store" })
      if (response.ok && !(await response.json()).pending) {
        remember(JUDGED_KEY, card.dataset.attemptId)
        window.location.reload()
        return
      }
    } catch {
      // A dropped request is retried on the next poll.
    }
    if (Date.now() - startedAt > POLL_GIVE_UP_MS) return
    delay = Math.min(delay * 1.5, POLL_MAX_MS)
    setTimeout(poll, delay)
  }
  setTimeout(poll, delay)
}

// After the reload, highlight the verdict once.
const announceJudgedResult = () => {
  const card = document.querySelector(".result-card[data-attempt-id]")
  if (!card || recall(JUDGED_KEY) !== card.dataset.attemptId) return

  remember(JUDGED_KEY, null)
  card.classList.add("just-judged")
}

const setUpSubmissionPage = () => {
  announceJudgedResult()
  watchPendingResult()
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", setUpSubmissionPage)
} else {
  setUpSubmissionPage()
}
