# typed: false
# frozen_string_literal: true

# Info owns public informational content.
scope module: :info, as: :info do
  # App info host. Hosts listed declaratively (DRY intentionally broken).
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).info_service.host, "info.app.localhost",
                     "info.umaxica.app",].compact do
    scope module: :app, as: :app do
      root to: "roots#index"

      # Deployment identifier endpoint.
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
          # `param: :public_id` addresses the resource by its opaque API identity,
          # distinct from the presentation slug; the route stays fully resourceful.
          resources :entries, only: %i(index show), param: :public_id

          # Machine-readable health and revision. The literal ".json" is part of the path, not a
          # Rails format token (`format: false`), mirroring the `.well-known/jwks.json` precedent.
          # These are JSON-only; the controllers answer 406 to any other `Accept`.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end

  # Corporate info host.
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).info_corporate.host, "info.com.localhost",
                     "info.umaxica.com",].compact do
    scope module: :com, as: :com do
      root to: "roots#index"

      # Deployment identifier endpoint.
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
          # `param: :public_id` addresses the resource by its opaque API identity,
          # distinct from the presentation slug; the route stays fully resourceful.
          resources :entries, only: %i(index show), param: :public_id

          # Machine-readable health and revision. The literal ".json" is part of the path, not a
          # Rails format token (`format: false`), mirroring the `.well-known/jwks.json` precedent.
          # These are JSON-only; the controllers answer 406 to any other `Accept`.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end

  # Staff info host.
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).info_staff.host, "info.org.localhost",
                     "info.umaxica.org",].compact do
    scope module: :org, as: :org do
      root to: "roots#index"

      # Deployment identifier endpoint.
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
          # `param: :public_id` addresses the resource by its opaque API identity,
          # distinct from the presentation slug; the route stays fully resourceful.
          resources :entries, only: %i(index show), param: :public_id

          # Machine-readable health and revision. The literal ".json" is part of the path, not a
          # Rails format token (`format: false`), mirroring the `.well-known/jwks.json` precedent.
          # These are JSON-only; the controllers answer 406 to any other `Accept`.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end
end
