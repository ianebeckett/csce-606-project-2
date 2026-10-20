module CodeReview
  # Base class for review failures; callers rescue this.
  class Error < StandardError; end
end
