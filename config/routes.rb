GloboDns::Application.routes.draw do
    devise_for :users, :controllers => { :sessions => 'sessions' }

    resources :domains do
        resources :records, :shallow => true do
            get 'resolve', :on => :member
        end
    end

    resources :domain_templates do
        resources :record_templates, :shallow => true
    end

    resources :views
    resources :users

    scope 'bind9', :as => 'bind9', :controller => 'bind9' do
        get  '',       :action => 'index'
        get  'config', :action => 'configuration'
        post 'export'
        post 'schedule_export'
    end

    match '/audits(/:action(/:id))' => 'audits#index', :as => :audits, :via => :get

    root :to => 'dashboard#index'
    
    get 'healthcheck' => lambda { |env| [200, {"Content-Type" => "text/plain"}, ["WORKING"]] }
    
end
