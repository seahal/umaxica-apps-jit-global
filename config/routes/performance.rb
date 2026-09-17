# typed: false
# frozen_string_literal: true

# Performance owns the server-side request performance dashboard (RailsPerformance::Engine), on its
# own dedicated host. Public canonical host: performance.umaxica.dev.
# Development host: performance.core.dev.localhost.
constraints host: [ENV["PUBLIC_PERFORMANCE_URL"], ENV["PRIVATE_PERFORMANCE_URL"],
                   "performance.core.dev.localhost",].compact do
  # `rails_performance` is a `group :development` gem (Gemfile); it is not in the test group's load
  # path, so the engine constant does not exist while running the test suite.
  if defined?(RailsPerformance::Engine)
    # The gem ships one config/routes.rb that does two unrelated things: it draws the engine's own
    # route set, and it then calls `Rails.application.routes.draw` to mount that engine at
    # `RailsPerformance.mount_at` with no host constraint and no flag to turn it off. Left alone,
    # /rails/performance answers on every host this application serves.
    #
    # config/application.rb drops the engine's `config/routes.rb` path so neither half runs, which
    # means the engine's own routes have to be drawn here. They are a verbatim copy of the gem's
    # list; `Security::Invariants::RailsPerformanceRouteInvariantTest` reads the gem's shipped file
    # and fails when the two diverge, so a gem upgrade that adds or renames a route cannot leave a
    # silently dead dashboard tab behind.
    RailsPerformance::Engine.routes.draw do
      get "/" => "rails_performance#index", :as => :rails_performance

      get "/requests" => "rails_performance#requests", :as => :rails_performance_requests
      get "/crashes" => "rails_performance#crashes", :as => :rails_performance_crashes
      get "/recent" => "rails_performance#recent", :as => :rails_performance_recent
      get "/slow" => "rails_performance#slow", :as => :rails_performance_slow

      get "/trace/:id" => "rails_performance#trace", :as => :rails_performance_trace
      get "/summary" => "rails_performance#summary", :as => :rails_performance_summary

      get "/sidekiq" => "rails_performance#sidekiq", :as => :rails_performance_sidekiq
      get "/delayed_job" => "rails_performance#delayed_job", :as => :rails_performance_delayed_job
      get "/grape" => "rails_performance#grape", :as => :rails_performance_grape
      get "/rake" => "rails_performance#rake", :as => :rails_performance_rake
      get "/custom" => "rails_performance#custom", :as => :rails_performance_custom
      get "/resources" => "rails_performance#resources", :as => :rails_performance_resources
    end

    # HTTP Basic Auth is applied as engine middleware in config/initializers/rails_performance.rb,
    # not by wrapping the engine in a Rack app here: a wrapped engine is no longer recognised as a
    # Rails app by `mount`, which then hands it a mount-relative PATH_INFO its own route set never
    # matches, so every request 404s past the engine. Mount it directly and keep the credential
    # check inside its own stack.
    mount RailsPerformance::Engine => "/", :as => :rails_performance
  end
end
