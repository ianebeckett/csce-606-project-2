class AddAllProblemsUnlockedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :all_problems_unlocked, :boolean, default: false, null: false
  end
end
