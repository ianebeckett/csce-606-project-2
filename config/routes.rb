Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "problems#index"
  # Display coding problems that are due for review
  get "reviews", to: "review_schedules#index", as: :reviews

  # Save a student's performance rating after practice
  patch "practice_sessions/:id/rate",
        to: "practice_session_ratings#update",
        as: :rate_practice_session


  resource :session, only: [ :new, :create, :destroy ]
  resource :registration, only: [ :new, :create ]
  resources :problems, only: [ :index, :show ] do
    resources :attempts, only: :create
  end
  resources :attempts, only: [ :index, :show ] do
    resource :code_review, only: :create
  end
end
