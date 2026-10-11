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

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Versioned BFF API.
      namespace :api do
        namespace :v0 do
          namespace :preferences do
            # These preference resources intentionally expose GET + PATCH only. Rails' `resource
            # ... only: :update` also exposes PUT, which is outside the existing OpenAPI contract.
            get :cookie, to: "cookies#show"
            patch :cookie, to: "cookies#update"
            get :theme, to: "themes#show"
            patch :theme, to: "themes#update"
            resource :dbsc, only: :create
          end

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

      # RP back-channel receiver. Canonical browser start is /sign/in + /sign/in/callback.
      namespace :oidc do
        namespace :backchannel do
          resource :logout, only: :create
        end
      end

      # Canonical browser sign-out ceremony (see config/routes/auth.rb for the pattern).
      scope path: "sign", as: :sign do
        get "in", to: "oidc/authorizations#show", as: :in
        get "in/callback", to: "oidc/callbacks#show", as: :in_callback
      end

      namespace :sign do
        # Canonical first-party RP start + callback (AuthBoundaryAuthorityMap).

        resource :termination, only: %i(show new edit create), path: "out", controller: :outs, as: :out
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

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Versioned BFF API.
      namespace :api do
        namespace :v0 do
          namespace :preferences do
            # Keep the established GET + PATCH contract; resource update would add an unapproved PUT.
            get :cookie, to: "cookies#show"
            patch :cookie, to: "cookies#update"
            get :theme, to: "themes#show"
            patch :theme, to: "themes#update"
            resource :dbsc, only: :create
          end

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

      # RP back-channel receiver. Canonical browser start is /sign/in + /sign/in/callback.
      namespace :oidc do
        namespace :backchannel do
          resource :logout, only: :create
        end
      end

      # Canonical browser sign-out ceremony (see config/routes/auth.rb for the pattern).
      scope path: "sign", as: :sign do
        get "in", to: "oidc/authorizations#show", as: :in
        get "in/callback", to: "oidc/callbacks#show", as: :in_callback
      end

      namespace :sign do
        # Canonical first-party RP start + callback (AuthBoundaryAuthorityMap).

        resource :termination, only: %i(show new edit create), path: "out", controller: :outs, as: :out
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

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Versioned BFF API.
      namespace :api do
        namespace :v0 do
          namespace :preferences do
            # Keep the established GET + PATCH contract; resource update would add an unapproved PUT.
            get :cookie, to: "cookies#show"
            patch :cookie, to: "cookies#update"
            get :theme, to: "themes#show"
            patch :theme, to: "themes#update"
            resource :dbsc, only: :create
          end

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

      # RP back-channel receiver. Canonical browser start is /sign/in + /sign/in/callback.
      namespace :oidc do
        namespace :backchannel do
          resource :logout, only: :create
        end
      end

      # Canonical browser sign-out ceremony (see config/routes/auth.rb for the pattern).
      scope path: "sign", as: :sign do
        get "in", to: "oidc/authorizations#show", as: :in
        get "in/callback", to: "oidc/callbacks#show", as: :in_callback
      end

      namespace :sign do
        # Canonical first-party RP start + callback (AuthBoundaryAuthorityMap).

        resource :termination, only: %i(show new edit create), path: "out", controller: :outs, as: :out
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
  constraints host: [ENV["PUBLIC_CORE_DEVELOPER_URL"], ENV["PRIVATE_CORE_DEVELOPER_URL"] || ENV["CORE_DEVELOPER_URL"],
                     "core.dev.localhost",].compact do
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
