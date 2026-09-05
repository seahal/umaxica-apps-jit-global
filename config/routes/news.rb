# typed: false
# frozen_string_literal: true

# News owns the public news content surface.
scope module: :news, as: :news do
  # App news host.
  constraints host: [ENV["PRIVATE_NEWS_SERVICE_URL"], "news.jp.umaxica.app", "news.app.localhost"].compact do
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

      # Public read-only news API.
      namespace :api do
        # Versioned news API.
        namespace :v0 do
          # Published news entries. `param: :public_id` addresses the resource by
          # its opaque API identity, distinct from the presentation slug; the
          # route stays fully resourceful.
          resources :entries, only: %i(index show), param: :public_id

          # Machine-readable health and revision. The literal ".json" is part of
          # the path, not a Rails format token (`format: false`), mirroring the
          # `.well-known/jwks.json` precedent. JSON-only; the controllers answer
          # 406 to any other `Accept`.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end

  # Corporate news host.
  constraints host: [ENV["PRIVATE_NEWS_CORPORATE_URL"], "news.jp.umaxica.com", "news.com.localhost"].compact do
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

      # Public read-only news API.
      namespace :api do
        # Versioned news API.
        namespace :v0 do
          # Published news entries. `param: :public_id` addresses the resource by
          # its opaque API identity, distinct from the presentation slug; the
          # route stays fully resourceful.
          resources :entries, only: %i(index show), param: :public_id

          # Machine-readable health and revision. The literal ".json" is part of
          # the path, not a Rails format token (`format: false`), mirroring the
          # `.well-known/jwks.json` precedent. JSON-only; the controllers answer
          # 406 to any other `Accept`.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end

  # Staff news host.
  constraints host: [ENV["PRIVATE_NEWS_STAFF_URL"], "news.jp.umaxica.org", "news.org.localhost"].compact do
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

      # Public read-only news API.
      namespace :api do
        # Versioned news API.
        namespace :v0 do
          # Published news entries. `param: :public_id` addresses the resource by
          # its opaque API identity, distinct from the presentation slug; the
          # route stays fully resourceful.
          resources :entries, only: %i(index show), param: :public_id

          # Machine-readable health and revision. The literal ".json" is part of
          # the path, not a Rails format token (`format: false`), mirroring the
          # `.well-known/jwks.json` precedent. JSON-only; the controllers answer
          # 406 to any other `Accept`.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end
end
