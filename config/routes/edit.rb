# typed: false
# frozen_string_literal: true

# Edit owns the staff Publishing management surface.
# Public canonical host: edit.umaxica.org. Development host: edit.org.localhost.
scope module: :edit, as: :edit do
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).edit_staff.host,
                     ENV["PUBLIC_EDIT_STAFF_URL"], ENV["PRIVATE_EDIT_STAFF_URL"],
                     "edit.umaxica.org", "edit.org.localhost",].compact do
    scope module: :org, as: :org do
      root to: "roots#index"

      resource :dashboard, only: :show

      resource :revision, only: :show, format: false

      resource :health, only: :show, format: false
      namespace :health do
        resource :liveness, only: :show, format: false
        resource :readiness, only: :show, format: false
        resource :startup, only: :show, format: false
      end

      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      namespace :api do
        namespace :v0 do
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end

      # Independent edit-org first-party RP. Canonical start is /sign/in + /sign/in/callback.
      namespace :oidc do
        namespace :backchannel do
          resource :logout, only: :create
        end
      end

      scope path: "sign", as: :sign do
        get "in", to: "oidc/authorizations#show", as: :in
        get "in/callback", to: "oidc/callbacks#show", as: :in_callback
      end

      namespace :sign do
        resource :termination, only: %i(show new edit create destroy), path: "out", controller: :outs, as: :out
      end

      # Staff Publishing CMS. Twelve explicit surface/audience cells (no route loops).
      # Locale is not a path segment; each cell maps Editions for that surface+audience.
      resource :publishing, only: [], module: :publishing do
        resource :info, only: [], module: :info do
          resource :app, only: [], module: :app do
            resources :entries, only: %i(index new create show edit update) do
              scope module: :entries do
                resources :publications, only: %i(create destroy)
                resource :archive, only: %i(create destroy)
              end
            end
          end
          resource :com, only: [], module: :com do
            resources :entries, only: %i(index new create show edit update) do
              scope module: :entries do
                resources :publications, only: %i(create destroy)
                resource :archive, only: %i(create destroy)
              end
            end
          end
          resource :org, only: [], module: :org do
            resources :entries, only: %i(index new create show edit update) do
              scope module: :entries do
                resources :publications, only: %i(create destroy)
                resource :archive, only: %i(create destroy)
              end
            end
          end
        end
        resource :docs, only: [], module: :docs do
          resource :app, only: [], module: :app do
            resources :entries, only: %i(index new create show edit update) do
              scope module: :entries do
                resources :publications, only: %i(create destroy)
                resource :archive, only: %i(create destroy)
              end
            end
          end
          resource :com, only: [], module: :com do
            resources :entries, only: %i(index new create show edit update) do
              scope module: :entries do
                resources :publications, only: %i(create destroy)
                resource :archive, only: %i(create destroy)
              end
            end
          end
          resource :org, only: [], module: :org do
            resources :entries, only: %i(index new create show edit update) do
              scope module: :entries do
                resources :publications, only: %i(create destroy)
                resource :archive, only: %i(create destroy)
              end
            end
          end
        end
        resource :news, only: [], module: :news do
          resource :app, only: [], module: :app do
            resources :entries, only: %i(index new create show edit update) do
              scope module: :entries do
                resources :publications, only: %i(create destroy)
                resource :archive, only: %i(create destroy)
              end
            end
          end
          resource :com, only: [], module: :com do
            resources :entries, only: %i(index new create show edit update) do
              scope module: :entries do
                resources :publications, only: %i(create destroy)
                resource :archive, only: %i(create destroy)
              end
            end
          end
          resource :org, only: [], module: :org do
            resources :entries, only: %i(index new create show edit update) do
              scope module: :entries do
                resources :publications, only: %i(create destroy)
                resource :archive, only: %i(create destroy)
              end
            end
          end
        end
        resource :help, only: [], module: :help do
          resource :app, only: [], module: :app do
            resources :entries, only: %i(index new create show edit update) do
              scope module: :entries do
                resources :publications, only: %i(create destroy)
                resource :archive, only: %i(create destroy)
              end
            end
          end
          resource :com, only: [], module: :com do
            resources :entries, only: %i(index new create show edit update) do
              scope module: :entries do
                resources :publications, only: %i(create destroy)
                resource :archive, only: %i(create destroy)
              end
            end
          end
          resource :org, only: [], module: :org do
            resources :entries, only: %i(index new create show edit update) do
              scope module: :entries do
                resources :publications, only: %i(create destroy)
                resource :archive, only: %i(create destroy)
              end
            end
          end
        end
      end
    end
  end
end
