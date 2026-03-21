Rails.application.routes.draw do
  resources :pizzas do
    resources :orders, only: [:new, :create]
  end

  resources :orders, only: [:index]

  root "pizzas#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
