# typed: false
# frozen_string_literal: true

# Core owns the BFF surface.
scope module: :core, as: :core do
  # Application BFF host.
  # Two request paths reach this surface with different Host headers, so both names are
  # listed. Requests forwarded by cloudflared carry the browser-facing PUBLIC_* site name,
  # which boot_config resolves; requests that arrive directly on the compose `frontend`
  # network carry the PRIVATE_* ingress alias. See docs/architecture/cloudflare-request-paths.md.
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).core_service.host,
                     ENV["PRIVATE_CORE_SERVICE_URL"],].compact do
    scope module: :app, as: :app do
      # Thin landing endpoint.
      root to: "roots#index"

      # Well-known public keys.
      namespace :well_known, path: ".well-known" do
        # JWKS endpoint; keep fixed JSON suffix.
        resource :jwks, only: :show, path: "jwks.json", format: false
      end

      # Deployment identifier endpoint.
      resource :revision, only: :show, format: false

      # Health summary and probes.
      resource :health, only: :show, format: false
      namespace :health do
        resource :liveness, only: :show, format: false
        resource :readiness, only: :show, format: false
        resource :startup, only: :show, format: false
      end

      # Crawler policy endpoint.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public web API: cookie consent, theme.
      namespace :web do
        namespace :v0 do
          resource :theme, only: %i(show update)
          resource :cookie, only: %i(show update)
        end
      end

      # Edge compatibility API.
      namespace :edge do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end

      # Versioned BFF API.
      namespace :api do
        namespace :v0 do
          # Machine-readable health and revision. The literal ".json" is part of the path, not a
          # Rails format token (`format: false`), mirroring the `.well-known/jwks.json` precedent.
          # These are JSON-only; the controllers answer 406 to any other `Accept`.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false

          # Session summary.
          resource :session, only: :show

          # Token lifecycle endpoints.
          namespace :token do
            # Token refresh endpoint.
            resource :renewal, only: :create, path: "refresh", controller: :refreshes, as: :refresh
          end
        end
      end

      # RP OIDC entrypoints.
      namespace :oidc do
        resource :authorization, only: :show
        resource :callback, only: :show

        # RP back-channel receiver.
        namespace :backchannel do
          resource :logout, only: :create
        end
      end

      # Canonical browser sign-out ceremony (see config/routes/auth.rb for the pattern).
      namespace :sign do
        resource :termination, only: %i(new edit create), path: "out", controller: :outs, as: :out do
          resource :completion, only: :show, path: "complete", module: :outs
        end
      end
    end
  end

  # Corporate BFF host.
  # Two request paths reach this surface with different Host headers, so both names are
  # listed. Requests forwarded by cloudflared carry the browser-facing PUBLIC_* site name,
  # which boot_config resolves; requests that arrive directly on the compose `frontend`
  # network carry the PRIVATE_* ingress alias. See docs/architecture/cloudflare-request-paths.md.
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).core_corporate.host,
                     ENV["PRIVATE_CORE_CORPORATE_URL"],].compact do
    scope module: :com, as: :com do
      # Thin landing endpoint.
      root to: "roots#index"

      # Well-known public keys.
      namespace :well_known, path: ".well-known" do
        # JWKS endpoint; keep fixed JSON suffix.
        resource :jwks, only: :show, path: "jwks.json", format: false
      end

      # Deployment identifier endpoint.
      resource :revision, only: :show, format: false

      # Health summary and probes.
      resource :health, only: :show, format: false
      namespace :health do
        resource :liveness, only: :show, format: false
        resource :readiness, only: :show, format: false
        resource :startup, only: :show, format: false
      end

      # Crawler policy endpoint.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public web API: cookie consent, theme.
      namespace :web do
        namespace :v0 do
          resource :theme, only: %i(show update)
          resource :cookie, only: %i(show update)
        end
      end

      # Edge compatibility API.
      namespace :edge do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end

      # Versioned BFF API.
      namespace :api do
        namespace :v0 do
          # Machine-readable health and revision. The literal ".json" is part of the path, not a
          # Rails format token (`format: false`), mirroring the `.well-known/jwks.json` precedent.
          # These are JSON-only; the controllers answer 406 to any other `Accept`.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false

          # Session summary.
          resource :session, only: :show

          # Token lifecycle endpoints.
          namespace :token do
            # Token refresh endpoint.
            resource :refresh, only: :create
          end
        end
      end

      # RP OIDC entrypoints.
      namespace :oidc do
        resource :callback, only: :show
        resource :authorization, only: :show

        # RP back-channel receiver.
        namespace :backchannel do
          resource :logout, only: :create
        end
      end

      # Canonical browser sign-out ceremony (see config/routes/auth.rb for the pattern).
      namespace :sign do
        resource :termination, only: %i(new edit create), path: "out", controller: :outs, as: :out do
          resource :completion, only: :show, path: "complete", module: :outs
        end
      end
    end
  end

  # Staff BFF host.
  # Two request paths reach this surface with different Host headers, so both names are
  # listed. Requests forwarded by cloudflared carry the browser-facing PUBLIC_* site name,
  # which boot_config resolves; requests that arrive directly on the compose `frontend`
  # network carry the PRIVATE_* ingress alias. See docs/architecture/cloudflare-request-paths.md.
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).core_staff.host,
                     ENV["PRIVATE_CORE_STAFF_URL"],].compact do
    scope module: :org, as: :org do
      # Thin landing endpoint.
      root to: "roots#index"

      # Well-known public keys.
      namespace :well_known, path: ".well-known" do
        # JWKS endpoint; keep fixed JSON suffix.
        resource :jwks, only: :show, path: "jwks.json", format: false
      end

      # Deployment identifier endpoint.
      resource :revision, only: :show, format: false

      # Health summary and probes.
      resource :health, only: :show, format: false
      namespace :health do
        resource :liveness, only: :show, format: false
        resource :readiness, only: :show, format: false
        resource :startup, only: :show, format: false
      end

      # Crawler policy endpoint.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Staff configuration endpoint.
      resource :configuration, only: :show

      # Public web API: cookie consent, theme.
      namespace :web do
        namespace :v0 do
          resource :theme, only: %i(show update)
          resource :cookie, only: %i(show update)
        end
      end

      # Edge compatibility API.
      namespace :edge do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end

      # Versioned BFF API.
      namespace :api do
        namespace :v0 do
          # Machine-readable health and revision. The literal ".json" is part of the path, not a
          # Rails format token (`format: false`), mirroring the `.well-known/jwks.json` precedent.
          # These are JSON-only; the controllers answer 406 to any other `Accept`.
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false

          # Session summary.
          resource :session, only: :show

          # Token lifecycle endpoints.
          namespace :token do
            # Token refresh endpoint.
            resource :refresh, only: :create
          end
        end
      end

      # RP OIDC entrypoints.
      namespace :oidc do
        resource :callback, only: :show
        resource :authorization, only: :show

        # RP back-channel receiver.
        namespace :backchannel do
          resource :logout, only: :create
        end
      end

      # Canonical browser sign-out ceremony (see config/routes/auth.rb for the pattern).
      namespace :sign do
        resource :termination, only: %i(new edit create), path: "out", controller: :outs, as: :out do
          resource :completion, only: :show, path: "complete", module: :outs
        end
      end
    end
  end

  # Network utility host.
  constraints host: [ENV["PRIVATE_CORE_NETWORK_URL"] || ENV["CORE_NETWORK_URL"], "core.net.localhost"].compact do
    scope module: :net, as: :network do
      # Thin landing endpoint.
      root to: "roots#index"

      # Deployment identifier endpoint.
      resource :revision, only: :show, format: false

      # Health summary and probes.
      resource :health, only: :show, format: false
      namespace :health do
        resource :liveness, only: :show, format: false
        resource :readiness, only: :show, format: false
        resource :startup, only: :show, format: false
      end

      # Machine-readable health and revision. The literal ".json" is part of the path, not a
      # Rails format token (`format: false`), mirroring the `.well-known/jwks.json` precedent.
      # These are JSON-only; the controllers answer 406 to any other `Accept`.
      namespace :api do
        namespace :v0 do
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  # Developer utility host.
  constraints host: [ENV["PRIVATE_CORE_DEVELOPER_URL"] || ENV["CORE_DEVELOPER_URL"], "core.dev.localhost"].compact do
    scope module: :dev, as: :developer do
      # Thin landing endpoint.
      root to: "roots#index"

      # Deployment identifier endpoint.
      resource :revision, only: :show, format: false

      # Health summary and probes.
      resource :health, only: :show, format: false
      namespace :health do
        resource :liveness, only: :show, format: false
        resource :readiness, only: :show, format: false
        resource :startup, only: :show, format: false
      end

      # Machine-readable health and revision. The literal ".json" is part of the path, not a
      # Rails format token (`format: false`), mirroring the `.well-known/jwks.json` precedent.
      # These are JSON-only; the controllers answer 406 to any other `Accept`.
      namespace :api do
        namespace :v0 do
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end
end
