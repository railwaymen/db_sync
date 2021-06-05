Rails.application.routes.draw do
  root 'products#index'
  resources :products do
    get :comparison, on: :collection
  end
end
