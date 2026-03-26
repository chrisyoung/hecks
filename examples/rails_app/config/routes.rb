Rails.application.routes.draw do
  resources :orders, only: [:index, :create] do
    post :cancel, on: :member
  end
  root "orders#index"

  namespace :admin do
    resources :pizzas, only: [:index, :create, :destroy] do
      post :add_topping, on: :member
    end
    post :pricing, to: "pizzas#update_pricing"
  end

  mount ActionCable.server => "/cable"
end
