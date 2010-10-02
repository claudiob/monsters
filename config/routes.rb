Monsters::Application.routes.draw do

  match 'monster', :to => 'monsters#monster'
  root :to => "monsters#index"

end
