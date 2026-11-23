class AccountsController < ApplicationController
  def show; end

  # Mock plan change: no payment step yet.
  def update
    current_user.change_role!(params.require(:role))
    redirect_to account_path, notice: "You're now on #{current_user.role}."
  rescue ActiveRecord::RecordInvalid, ActionController::ParameterMissing
    redirect_to account_path, alert: "That plan isn't available."
  end

  def problem_access
    unlocked = ActiveModel::Type::Boolean.new.cast(params[:unlocked]) || false
    current_user.update!(all_problems_unlocked: unlocked)
    redirect_to account_path, notice: unlocked ? "All problems are unlocked." : "Problems unlock by roadmap again."
  end
end
