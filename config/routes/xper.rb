# typed: false
# frozen_string_literal: true

# Experience Phase 0: independent host boundaries with no credential lifecycle.
scope module: :xper, as: :xper do
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).xper_service.host,
                     ENV["PRIVATE_XPER_SERVICE_URL"], "xper.app.localhost",].compact do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :health, only: :show, format: false
      namespace :health do
        resource :liveness, only: :show, format: false
        resource :readiness, only: :show, format: false
        resource :startup, only: :show, format: false
      end
      resource :revision, only: :show, format: false
      namespace :api do
        namespace :v0 do
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      resources :robots, only: :index, path: "robots.txt", format: false
      resources :sitemaps, only: :index, path: "sitemap.xml", format: false
    end
  end

  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).xper_corporate.host,
                     ENV["PRIVATE_XPER_CORPORATE_URL"], "xper.com.localhost",].compact do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :health, only: :show, format: false
      namespace :health do
        resource :liveness, only: :show, format: false
        resource :readiness, only: :show, format: false
        resource :startup, only: :show, format: false
      end
      resource :revision, only: :show, format: false
      namespace :api do
        namespace :v0 do
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      resources :robots, only: :index, path: "robots.txt", format: false
      resources :sitemaps, only: :index, path: "sitemap.xml", format: false
    end
  end

  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).xper_staff.host,
                     ENV["PRIVATE_XPER_STAFF_URL"], "xper.org.localhost",].compact do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :health, only: :show, format: false
      namespace :health do
        resource :liveness, only: :show, format: false
        resource :readiness, only: :show, format: false
        resource :startup, only: :show, format: false
      end
      resource :revision, only: :show, format: false
      namespace :api do
        namespace :v0 do
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      resources :robots, only: :index, path: "robots.txt", format: false
      resources :sitemaps, only: :index, path: "sitemap.xml", format: false
    end
  end
end
