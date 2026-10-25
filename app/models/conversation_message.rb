class ConversationMessage < ApplicationRecord
  belongs_to :practice_session
  belongs_to :attempt, optional: true
end
