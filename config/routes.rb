Rails.application.routes.draw do
  root "dashboard#index"
  resource :session, only: [:new, :create, :destroy]
  resource :setup, only: [:new, :create], controller: "setup"
  post "timezone" => "timezone#update"
  resources :servers do
    post :check_now, on: :member
    get :extended_metrics, on: :member
    post :reorder, on: :collection
  end
  resources :shortcuts, except: [:show] do
    post :reorder, on: :collection
  end
  post "monitoring/servers/toggle" => "monitoring#toggle_servers", as: :toggle_servers_checks
  post "monitoring/servers/run" => "monitoring#run_servers", as: :run_servers_checks
  post "monitoring/shortcuts/toggle" => "monitoring#toggle_shortcuts", as: :toggle_shortcuts_checks
  post "monitoring/shortcuts/run" => "monitoring#run_shortcuts", as: :run_shortcuts_checks
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
end
