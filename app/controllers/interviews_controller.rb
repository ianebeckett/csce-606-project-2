class InterviewsController < ApplicationController
  include InterviewAccess

  def show
    @practice_session = current_user.practice_sessions.for_today(@problem)
    @practice_session.start_interview!
    @attempt = Attempt.new(code: @problem.starter_code, language: Attempt::LANGUAGE)
  end
end
