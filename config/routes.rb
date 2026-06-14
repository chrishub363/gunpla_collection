Rails.application.routes.draw do
  # Health check for load balancers and uptime monitors
  get "up" => "rails/health#show", as: :rails_health_check

  root "kits#index"
  get "/collection", to: "kits#index", defaults: { tab: "collection" }
  get "/wishlist",   to: "kits#index", defaults: { tab: "wishlist" }
  get "/pick",       to: "kits#pick"
end
