Monsters::Application.routes.draw do

  resources :monsters
  root :to => "monsters#index"

end
