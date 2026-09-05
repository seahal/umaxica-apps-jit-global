# typed: false
# frozen_string_literal: true

# Side owns the Rails control-plane surface.
scope module: :side, as: :side do
  # App control-plane host. Hosts listed declaratively (DRY intentionally broken).
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).side_service.host, "side.app.localhost"].compact do
    # App surface controllers.
    scope module: :app, as: :app do
      # Thin landing endpoint.
      root to: "roots#index"

      # Model Context Protocol endpoint. The MCP spec requires a single path serving POST; the
      # transport carries every protocol method in the JSON-RPC body, so one create action is the
      # whole endpoint.
      resource :mcp, only: :create

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

      # Machine-readable health and revision. The literal ".json" is part of the path, not a Rails
      # format token (`format: false`), mirroring the `.well-known/jwks.json` precedent. These are
      # JSON-only; the controllers answer 406 to any other `Accept`.
      namespace(:api) do
        namespace(:v0) do
          resource(:health, only: :show, path: "health.json", format: false)
          resource(:revision, only: :show, path: "revision.json", format: false)
        end
      end

      # Crawler policy endpoint; keep fixed public path.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint; keep fixed public path.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # Control-plane settings index.
      resource :settings, only: :show

      # Signed-in dashboard.
      resource :dashboard, only: :show

      # Canonical browser sign-out ceremony (see config/routes/auth.rb for the pattern).
      namespace :sign do
        resource :termination, only: %i(new edit create), path: "out", controller: :outs, as: :out do
          resource :completion, only: :show, path: "complete", module: :outs
        end
      end

      # RP login start: redirects to Base /oauth/authorize.
      namespace :oidc do
        resource :authorization, only: :show
        resource :callback, only: :show
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # PWA offline fallback. This is the route form Rails' own application generator emits, kept
      # verbatim except for the leading slash on the controller, which escapes the enclosing
      # `scope(module:)`. Approved exception to the resourceful routing rule; do not reshape it into
      # `resource`. See adr/pwa-offline-route-exception.md.
      get("service-worker", to: "/rails/pwa#service_worker", as: :pwa_service_worker)
      get("offline", to: "/rails/pwa#offline", as: :pwa_offline)
    end
  end

  # Corporate control-plane host.
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).side_corporate.host,
                     "side.com.localhost",].compact do
    # Corporate surface controllers.
    scope module: :com, as: :com do
      # Thin landing endpoint.
      root to: "roots#index"

      # Model Context Protocol endpoint. The MCP spec requires a single path serving POST; the
      # transport carries every protocol method in the JSON-RPC body, so one create action is the
      # whole endpoint.
      resource :mcp, only: :create

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

      # Machine-readable health and revision. The literal ".json" is part of the path, not a Rails
      # format token (`format: false`), mirroring the `.well-known/jwks.json` precedent. These are
      # JSON-only; the controllers answer 406 to any other `Accept`.
      namespace(:api) do
        namespace(:v0) do
          resource(:health, only: :show, path: "health.json", format: false)
          resource(:revision, only: :show, path: "revision.json", format: false)
        end
      end

      # Crawler policy endpoint; keep fixed public path.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint; keep fixed public path.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # Control-plane settings index.
      resource :settings, only: :show

      # Signed-in dashboard.
      resource :dashboard, only: :show

      # Canonical browser sign-out ceremony (see config/routes/auth.rb for the pattern).
      namespace :sign do
        resource :termination, only: %i(new edit create), path: "out", controller: :outs, as: :out do
          resource :completion, only: :show, path: "complete", module: :outs
        end
      end

      # RP login start: redirects to Base /oauth/authorize.
      namespace :oidc do
        resource :authorization, only: :show
        resource :callback, only: :show
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # PWA offline fallback. This is the route form Rails' own application generator emits, kept
      # verbatim except for the leading slash on the controller, which escapes the enclosing
      # `scope(module:)`. Approved exception to the resourceful routing rule; do not reshape it into
      # `resource`. See adr/pwa-offline-route-exception.md.
      get("service-worker", to: "/rails/pwa#service_worker", as: :pwa_service_worker)
      get("offline", to: "/rails/pwa#offline", as: :pwa_offline)
    end
  end

  # Staff control-plane host.
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).side_staff.host, "side.org.localhost"].compact do
    # Staff surface controllers.
    scope module: :org, as: :org do
      # Thin landing endpoint.
      root to: "roots#index"

      # Model Context Protocol endpoint. The MCP spec requires a single path serving POST; the
      # transport carries every protocol method in the JSON-RPC body, so one create action is the
      # whole endpoint.
      resource :mcp, only: :create

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

      # Machine-readable health and revision. The literal ".json" is part of the path, not a Rails
      # format token (`format: false`), mirroring the `.well-known/jwks.json` precedent. These are
      # JSON-only; the controllers answer 406 to any other `Accept`.
      namespace(:api) do
        namespace(:v0) do
          resource(:health, only: :show, path: "health.json", format: false)
          resource(:revision, only: :show, path: "revision.json", format: false)
        end
      end

      # Crawler policy endpoint; keep fixed public path.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint; keep fixed public path.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # Control-plane settings index.
      resource :settings, only: :show

      # Signed-in dashboard.
      resource :dashboard, only: :show

      # Canonical browser sign-out ceremony (see config/routes/auth.rb for the pattern).
      namespace :sign do
        resource :termination, only: %i(new edit create), path: "out", controller: :outs, as: :out do
          resource :completion, only: :show, path: "complete", module: :outs
        end
      end

      # RP login start: redirects to Base /oauth/authorize.
      namespace :oidc do
        resource :authorization, only: :show
        resource :callback, only: :show
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # PWA offline fallback. This is the route form Rails' own application generator emits, kept
      # verbatim except for the leading slash on the controller, which escapes the enclosing
      # `scope(module:)`. Approved exception to the resourceful routing rule; do not reshape it into
      # `resource`. See adr/pwa-offline-route-exception.md.
      get("service-worker", to: "/rails/pwa#service_worker", as: :pwa_service_worker)
      get("offline", to: "/rails/pwa#offline", as: :pwa_offline)
    end
  end
end
