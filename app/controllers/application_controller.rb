class ApplicationController < ActionController::Base
  before_action :require_login
  helper_method :current_user

  allow_browser versions: :modern

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_login
    redirect_to new_session_path, alert: "Please sign in to practice." unless current_user
  end
end
