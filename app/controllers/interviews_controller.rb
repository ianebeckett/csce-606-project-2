class InterviewsController < ApplicationController
  include InterviewAccess

  def show
    @practice_session = current_user.practice_sessions.for_today(@problem)
    @practice_session.start_interview!
    @language = Attempt::LANGUAGES.include?(params[:language]) ? params[:language] : Attempt::LANGUAGE
    @attempt = Attempt.new(code: @problem.starter_code_for(@language), language: @language)
  end
end
