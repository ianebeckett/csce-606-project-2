class RegistrationsController < ApplicationController
  skip_before_action :require_login

  def new
    @user = User.new
  end

  def create
    @user = User.new(params.require(:user).permit(:email, :password, :password_confirmation))
    if @user.save
      reset_session
      session[:user_id] = @user.id
      redirect_to problems_path, notice: "Account created."
    else
      render :new, status: :unprocessable_content
    end
  end
end
