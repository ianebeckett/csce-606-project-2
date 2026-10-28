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
