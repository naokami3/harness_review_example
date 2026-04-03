Rails.application.routes.draw do
  post "auth/register", to: "auth#register"
  post "auth/login", to: "auth#login"

  resources :tasks, only: [:index, :create, :show, :update, :destroy] do
    collection do
      get "by_status/:status", action: :by_status
    end
  end
end
