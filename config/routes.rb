Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "problems#index"
  resource :session, only: [ :new, :create, :destroy ]
  resource :registration, only: [ :new, :create ]
  resources :problems, only: [ :index, :show ] do
    resources :attempts, only: :create
    resources :coaching_messages, only: :create
  end
  resources :attempts, only: [ :index, :show ] do
    resource :code_review, only: :create
  end
  resources :history, only: [ :index, :show ]
end
