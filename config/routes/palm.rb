# typed: false
# frozen_string_literal: true

# Palm owns the browser RP and machine health surface.
scope module: :palm, as: :palm do
  # Palm app host. Hosts listed declaratively (DRY intentionally broken).
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).palm_service.host, "palm.app.localhost"].compact do
    # App surface controllers.
    scope module: :app, as: :app do
      # Thin landing endpoint.
      root to: "roots#index"

      # Protected Browser RP landing page.
      resource :dashboard, only: :show

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

      # Crawler policy endpoint.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint.
      resource :sitemap, only: :show, path: "sitemap.xml"

      namespace :well_known, path: ".well-known" do
        resource :jwks, only: :show, path: "jwks.json", format: false
      end

      # Authorization-code callback for the Palm browser RP.
      # R5-WU16 matching-session RP cookie purge after OP logout.
      namespace :oidc do
        resource :callback, only: :show
        # R5-WU10 server-to-server OIDC Back-Channel Logout receiver for this RP cell.
        resources :closures, only: :create
      end

      # Neutral Browser RP entry: GET renders the page, POST starts the server-owned flow.
      scope path: "sign", as: :sign do
        get "", to: "sign/entries#show", as: :show
        post "", to: "sign/entries#create", as: :create
        # D-153: one generic landing for expected abnormal endings of the sign flow.
        resource :interruption, only: :show, module: :sign
      end

      # Browser RP sign-out start and completion.
      namespace :sign do
        resource :termination, only: %i(show new edit create), path: "out", controller: :outs, as: :out
        resource :out_completion, only: :show, path: "out/completion",
                                  controller: "out/completions"
      end

      # Browser CSP report sink.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # PWA offline fallback. This is the route form Rails' own application generator emits, kept
      # verbatim except for the leading slash on the controller, which escapes the enclosing
      # `scope(module:)`. Approved exception to the resourceful routing rule; do not reshape it into
      # `resource`. See adr/pwa-offline-route-exception.md.
      get("service-worker", to: "/rails/pwa#service_worker", as: :pwa_service_worker)
      get("offline", to: "/rails/pwa#offline", as: :pwa_offline)

      # Machine-readable health and revision endpoints remain available under the API namespace.
      namespace :api do
        # Versioned machine endpoints.
        namespace :v0 do
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
