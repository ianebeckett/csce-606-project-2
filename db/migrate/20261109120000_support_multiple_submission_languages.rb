class SupportMultipleSubmissionLanguages < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :attempts, name: "attempts_ruby_only"
    add_check_constraint :attempts, "language IN ('ruby', 'python', 'go', 'cpp')",
      name: "attempts_supported_languages"
  end

  def down
    remove_check_constraint :attempts, name: "attempts_supported_languages"
    add_check_constraint :attempts, "language = 'ruby'", name: "attempts_ruby_only"
  end
end
