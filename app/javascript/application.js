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


// AI chat: keep the newest message in view.
const scrollChatToEnd = () => {
  document.querySelectorAll("[data-chat-log]").forEach((log) => {
    log.scrollTop = log.scrollHeight
  })
}

const setUpChatPage = () => {
  scrollChatToEnd()
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", setUpChatPage)
} else {
  setUpChatPage()
}
