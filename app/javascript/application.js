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
