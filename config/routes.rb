Rails.application.routes.draw do
  root 'main#index'
  get 'main/index'

  get 'callback' => 'main#callback'
  get 'properties' => 'main#properties'
  post 'properties' => 'main#properties'

  get 'diagram' => 'main#diagram'
  post 'diagram' => 'main#diagram'

end
