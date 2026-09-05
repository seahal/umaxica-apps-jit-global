# typed: false
# frozen_string_literal: true

# Help owns the public help content surface.
scope module: :help, as: :help do
  # App help host. Hosts listed declaratively (DRY intentionally broken).
  constraints host: [
    Rails.configuration.x.boot_config.fetch(:hosts).help_service.host,
    "help.jp.umaxica.app",
    "help.app.localhost",
  ].compact do
    # App surface controllers.
    scope module: :app, as: :app do
      # Thin landing endpoint.
      root to: "roots#index"

      # Deployment identifier endpoint.
      resource :revision, only: :show, format: false

      # Basic health summary.
      resource :health, only: :show, format: false

      # Machine-readable health probes.
      namespace :health do
        # Process liveness probe.
        resource :liveness, only: :show, format: false

        # Dependency readiness probe.
        resource :readiness, only: :show, format: false

        # Boot/startup probe.
        resource :startup, only: :show, format: false
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public read-only help API.
      namespace :api do
        # Versioned help API.
        namespace :v0 do
          # Published help entries, addressed by opaque public_id.
          resources :entries, only: %i(index show), param: :public_id

          # Machine-readable health and revision. The literal ".json" is part of
          # the path, not a Rails format token (`format: false`), mirroring the
          # `.well-known/jwks.json` precedent. JSON-only; 406 to any other Accept.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end

  # Corporate help host.
  constraints host: [
    Rails.configuration.x.boot_config.fetch(:hosts).help_corporate.host,
    "help.jp.umaxica.com",
    "help.com.localhost",
  ].compact do
    # Corporate surface controllers.
    scope module: :com, as: :com do
      # Thin landing endpoint.
      root to: "roots#index"

      # Deployment identifier endpoint.
      resource :revision, only: :show, format: false

      # Basic health summary.
      resource :health, only: :show, format: false

      # Machine-readable health probes.
      namespace :health do
        # Process liveness probe.
        resource :liveness, only: :show, format: false

        # Dependency readiness probe.
        resource :readiness, only: :show, format: false

        # Boot/startup probe.
        resource :startup, only: :show, format: false
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public read-only help API.
      namespace :api do
        # Versioned help API.
        namespace :v0 do
          # Published help entries, addressed by opaque public_id.
          resources :entries, only: %i(index show), param: :public_id

          # Machine-readable health and revision. The literal ".json" is part of
          # the path, not a Rails format token (`format: false`), mirroring the
          # `.well-known/jwks.json` precedent. JSON-only; 406 to any other Accept.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end

  # Staff help host.
  constraints host: [
    Rails.configuration.x.boot_config.fetch(:hosts).help_staff.host,
    "help.jp.umaxica.org",
    "help.org.localhost",
  ].compact do
    # Staff surface controllers.
    scope module: :org, as: :org do
      # Thin landing endpoint.
      root to: "roots#index"

      # Deployment identifier endpoint.
      resource :revision, only: :show, format: false

      # Basic health summary.
      resource :health, only: :show, format: false

      # Machine-readable health probes.
      namespace :health do
        # Process liveness probe.
        resource :liveness, only: :show, format: false

        # Dependency readiness probe.
        resource :readiness, only: :show, format: false

        # Boot/startup probe.
        resource :startup, only: :show, format: false
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public read-only help API.
      namespace :api do
        # Versioned help API.
        namespace :v0 do
          # Published help entries, addressed by opaque public_id.
          resources :entries, only: %i(index show), param: :public_id

          # Machine-readable health and revision. The literal ".json" is part of
          # the path, not a Rails format token (`format: false`), mirroring the
          # `.well-known/jwks.json` precedent. JSON-only; 406 to any other Accept.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end
end
