# typed: false
# frozen_string_literal: true

# Docs owns the public documentation content surface.
scope module: :docs, as: :docs do
  # App documentation host.
  constraints host: [ENV["PRIVATE_DOCS_SERVICE_URL"], "docs.jp.umaxica.app", "docs.app.localhost"].compact do
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

      # Public read-only documentation API.
      namespace :api do
        # Versioned documentation API.
        namespace :v0 do
          # Published documentation entries. `param: :public_id` addresses the
          # resource by its opaque API identity, distinct from the presentation
          # slug; the route stays fully resourceful.
          resources :entries, only: %i(index show), param: :public_id

          # Machine-readable health and revision. The literal ".json" is part of the
          # path, not a Rails format token (`format: false`), mirroring the
          # `.well-known/jwks.json` precedent. JSON-only; the controllers answer 406
          # to any other `Accept`.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end

  # Corporate documentation host.
  constraints host: [ENV["PRIVATE_DOCS_CORPORATE_URL"], "docs.jp.umaxica.com", "docs.com.localhost"].compact do
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

      # Public read-only documentation API.
      namespace :api do
        # Versioned documentation API.
        namespace :v0 do
          # Published documentation entries, addressed by opaque public_id.
          resources :entries, only: %i(index show), param: :public_id

          # Machine-readable health and revision. The literal ".json" is part of the
          # path, not a Rails format token (`format: false`), mirroring the
          # `.well-known/jwks.json` precedent. JSON-only; the controllers answer 406
          # to any other `Accept`.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end

  # Staff documentation host.
  constraints host: [ENV["PRIVATE_DOCS_STAFF_URL"], "docs.jp.umaxica.org", "docs.org.localhost"].compact do
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

      # Public read-only documentation API.
      namespace :api do
        # Versioned documentation API.
        namespace :v0 do
          # Published documentation entries, addressed by opaque public_id.
          resources :entries, only: %i(index show), param: :public_id

          # Machine-readable health and revision. The literal ".json" is part of the
          # path, not a Rails format token (`format: false`), mirroring the
          # `.well-known/jwks.json` precedent. JSON-only; the controllers answer 406
          # to any other `Accept`.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end
end
