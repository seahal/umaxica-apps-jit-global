# typed: false
# frozen_string_literal: true

# Auth owns the credential gateway surfaces. Base is the sole IdP /
# Authorization Server; Auth surfaces handle credential ceremonies and do not
# own RP authority.
scope(module: :auth, as: :auth) do
  # User credential gateway host. Hosts listed declaratively (DRY intentionally broken).
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).auth_service.host, ENV["PUBLIC_AUTH_SERVICE_URL"],
           "auth.app.localhost",].compact,
  ) do
    scope(module: :app, as: :app) do
      root "roots#index"
      resource :dashboard, only: :show
      resources :billings, only: :index

      namespace(:well_known, path: ".well-known") do
        resource(:jwks, only: :show, path: "jwks.json", format: false)
      end

      # Deployment identifier endpoint.
      resource(:revision, only: :show, format: false)

      resource(:health, only: :show, format: false)
      namespace(:health) do
        resource(:liveness, only: :show, format: false)
        resource(:readiness, only: :show, format: false)
        resource(:startup, only: :show, format: false)
      end

      # Machine-readable health and revision. The literal ".json" is part of the path, not a Rails
      # format token (`format: false`), mirroring the `.well-known/jwks.json` precedent above.
      # These are JSON-only; the controllers answer 406 to any other `Accept`.
      namespace(:api) do
        namespace(:v0) do
          resource(:health, only: :show, path: "health.json", format: false)
          resource(:revision, only: :show, path: "revision.json", format: false)
        end
      end

      resources(:robots, only: :index, path: "robots.txt")
      resource(:sitemap, only: :show, path: "sitemap.xml")
      resource(:csp_violation_report, only: :create, path: "csp-violation-report")

      # PWA offline fallback. This is the route form Rails' own application generator emits, kept
      # verbatim except for the leading slash on the controller, which escapes the enclosing
      # `scope(module:)`. Approved exception to the resourceful routing rule; do not reshape it into
      # `resource`. See adr/pwa-offline-route-exception.md.
      get("service-worker", to: "/rails/pwa#service_worker", as: :pwa_service_worker)
      get("offline", to: "/rails/pwa#offline", as: :pwa_offline)

      namespace :apple do
        resources :notifications, only: :create
      end

      # Canonical ceremony entrypoints and authed-out confirmation/cleanup.
      namespace :sign do
        resource :registration, only: :show, path: "up", controller: :ups, as: :up
        resource :session, only: :show, path: "in", controller: :ins, as: :in
        resource :termination, only: %i(new edit create destroy), path: "out", controller: :outs, as: :out do
          resource :completion, only: :show, path: "complete", module: :outs
        end
      end

      namespace(:oidc) do
        resource(:authorization, only: :show)
        resource(:callback, only: :show)

        namespace(:backchannel) do
          resource(:logout, only: :create)
        end
      end

      # Public web API: OTP delivery, cookie consent, theme.
      namespace :web do
        namespace :v0 do
          namespace :in do
            namespace :email do
              resource :otp, only: :create
            end
          end

          resource :theme, only: %i(show update)
          resource :cookie, only: %i(show update)
        end
      end

      # Edge compatibility API: token lifecycle management.
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :status, only: :show, path: "check", controller: :checks, as: :check
            resource :dbsc, only: :create
          end
        end
      end

      # Sign-up and sign-in ceremonies.
      namespace :sign do
        # Auth-up ceremony.
        namespace(:up) do
          resource(:email, only: %i(new create))
          resource(:telephone, only: %i(new create))

          namespace(:guard) do
            resource(:apple, only: :show)
            resource(:google, only: :show)
            resource(:email, only: :show)
            resource(:telephone, only: :show)
          end

          namespace(:check) do
            namespace(:apple) do
              resource(:confirmation, only: %i(show update destroy))
              resource(:birthdate, only: %i(show update destroy))
            end

            namespace(:google) do
              resource(:confirmation, only: %i(show update destroy))
              resource(:birthdate, only: %i(show update destroy))
            end

            namespace(:email) do
              resource(:otp, only: %i(show create update destroy))
              resource(:birthdate, only: %i(show update destroy))
            end

            namespace(:telephone) do
              resource(:otp, only: %i(show create update destroy))
              resource(:passkey, only: %i(show create update destroy))
              resource(:passcode, only: %i(show update destroy))
              resource(:birthdate, only: %i(show update destroy))
            end
          end
        end

        # Sign-in ceremony.
        namespace :in do
          resource :email, only: %i(new create edit update)

          resource :passkey, only: :new
          namespace :passkey do
            resource :options, only: :create
            resource :verification, only: :create
          end

          resource :secret, only: %i(new create)
          resource :session, only: %i(show update destroy)

          resource :guard, only: :show
          resource :check, only: :show

          resource :challenge, only: :show
          namespace :challenge do
            resource :totp, only: %i(new create)
            resource :passkey, only: %i(new create)
          end
        end
      end

      namespace(:social) do
        # Non-resourceful exception: OmniAuth middleware owns these fixed provider callback paths.
        get(
          "google/callback",
          to: "/auth/app/omniauth/omniauth_callbacks#omniauth",
          as: :google_callback,
          defaults: { provider: "google" },
        )

        get(
          "apple/callback",
          to: "/auth/app/omniauth/omniauth_callbacks#omniauth",
          as: :apple_callback,
          defaults: { provider: "apple" },
        )

        get(
          "failure",
          to: "/auth/app/omniauth/omniauth_callbacks#failure",
          as: :failure,
        )

        # Ceremony start. session = sign-in intent, registration = sign-up
        # entry; the provider is carried by route defaults.
        #
        # POST only, and deliberately so: the press of an in-application button
        # supplies the CSRF token the OmniAuth request phase requires, and the
        # ceremony hands that same POST on with a 307. There is no GET entry, so
        # a link cannot start an authentication ceremony. People choose their
        # provider on the sign-in or sign-up page.
        scope :google, as: :google, defaults: { provider: "google", intent: "login" } do
          resource :session, only: :create, controller: :sessions
          resource :registration, only: :create, controller: :registrations, defaults: { entry: "auth_up" }
        end

        scope :apple, as: :apple, defaults: { provider: "apple", intent: "login" } do
          resource :session, only: :create, controller: :sessions
          resource :registration, only: :create, controller: :registrations, defaults: { entry: "auth_up" }
        end
      end

      # Step-up verification.
      resource :verification, only: :show
      namespace :verification do
        resource :cancellation, only: :create
      end
      namespace :verification do
        resource :setup, only: :new
        resource :passkey, only: %i(new create)
        resource :totp, only: %i(new create)

        resources :emails, only: %i(new create edit update) do
          resource :redelivery, only: :create
        end
      end

      # Settings and credential management.
      resource :settings, only: :show
      namespace :settings do
        resources :totps, only: %i(index new create edit update destroy)

        # TODO: cache passkeys/passkey lookups.
        resources :passkeys do
          resource :removal, only: :create
        end

        namespace :passkeys do
          resource :options, only: :create
          resource :verification, only: :create
        end

        resource :apple, only: %i(show edit create destroy)
        resource :google, only: %i(show edit create destroy)
      end
    end
  end

  # Corporate credential gateway host.
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).auth_corporate.host,
           ENV["PUBLIC_AUTH_CORPORATE_URL"], "auth.com.localhost",].compact,
  ) do
    scope(module: :com, as: :com) do
      root "roots#index"
      resource :dashboard, only: :show

      namespace(:well_known, path: ".well-known") do
        resource(:jwks, only: :show, path: "jwks.json", format: false)
      end

      # Deployment identifier endpoint.
      resource(:revision, only: :show, format: false)

      resource(:health, only: :show, format: false)
      namespace(:health) do
        resource(:liveness, only: :show, format: false)
        resource(:readiness, only: :show, format: false)
        resource(:startup, only: :show, format: false)
      end

      # Machine-readable health and revision. The literal ".json" is part of the path, not a Rails
      # format token (`format: false`), mirroring the `.well-known/jwks.json` precedent above.
      # These are JSON-only; the controllers answer 406 to any other `Accept`.
      namespace(:api) do
        namespace(:v0) do
          resource(:health, only: :show, path: "health.json", format: false)
          resource(:revision, only: :show, path: "revision.json", format: false)
        end
      end

      resources(:robots, only: :index, path: "robots.txt")
      resource(:sitemap, only: :show, path: "sitemap.xml")
      resource(:csp_violation_report, only: :create, path: "csp-violation-report")

      # PWA offline fallback. This is the route form Rails' own application generator emits, kept
      # verbatim except for the leading slash on the controller, which escapes the enclosing
      # `scope(module:)`. Approved exception to the resourceful routing rule; do not reshape it into
      # `resource`. See adr/pwa-offline-route-exception.md.
      get("service-worker", to: "/rails/pwa#service_worker", as: :pwa_service_worker)
      get("offline", to: "/rails/pwa#offline", as: :pwa_offline)

      # Canonical ceremony entrypoints and authed-out confirmation.
      namespace :sign do
        resource :registration, only: :show, path: "up", controller: :ups, as: :up
        resource :session, only: :show, path: "in", controller: :ins, as: :in
        resource :termination, only: %i(new edit create destroy), path: "out", controller: :outs, as: :out do
          resource :completion, only: :show, path: "complete", module: :outs
        end
      end

      namespace(:oidc) do
        resource(:authorization, only: :show)
        resource(:callback, only: :show)

        namespace(:backchannel) do
          resource(:logout, only: :create)
        end
      end

      # Public web API: OTP delivery, cookie consent, theme.
      namespace :web do
        namespace :v0 do
          namespace :in do
            namespace :email do
              resource :otp, only: :create
            end
          end

          resource :theme, only: %i(show update)
          resource :cookie, only: %i(show update)
        end
      end

      # Edge compatibility API: token lifecycle management.
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :status, only: :show, path: "check", controller: :checks, as: :check
            resource :dbsc, only: :create
          end
        end
      end

      # Sign-up and sign-in ceremonies.
      namespace :sign do
        # Auth-up ceremony.
        namespace(:up) do
          resource(:email, only: %i(new create))
          resource(:telephone, only: %i(new create))

          namespace(:guard) do
            resource(:email, only: :show)
            resource(:telephone, only: :show)
          end

          namespace(:check) do
            namespace(:email) do
              resource(:otp, only: %i(show create update destroy))
              resource(:birthdate, only: %i(show update destroy))
            end

            namespace(:telephone) do
              resource(:otp, only: %i(show create update destroy))
              resource(:passkey, only: %i(show create update destroy))
              resource(:passcode, only: %i(show update destroy))
              resource(:birthdate, only: %i(show update destroy))
            end
          end
        end

        # Sign-in ceremony.
        namespace :in do
          resource :email, only: %i(new create edit update)

          resource :passkey, only: :new
          namespace :passkey do
            resource :options, only: :create
            resource :verification, only: :create
          end

          resource :secret, only: %i(new create)
          resource :session, only: %i(show update destroy)

          resource :guard, only: :show
          resource :check, only: :show

          resource :challenge, only: :show

          namespace :challenge do
            resource :passkey, only: %i(new create)
          end
        end
      end

      # Step-up verification.
      resource :verification, only: :show
      namespace :verification do
        resource :cancellation, only: :create
      end
      namespace :verification do
        resource :setup, only: :new
        resource :passkey, only: %i(new create)

        resources :emails, only: %i(new create edit update) do
          resource :redelivery, only: :create
        end
      end

      # Settings and credential management.
      resource :settings, only: :show
      namespace :settings do
        resources :passkeys do
          resource :removal, only: :create
        end

        namespace :passkeys do
          resource :options, only: :create
          resource :verification, only: :create
        end
      end
    end
  end

  # Staff credential gateway host.
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).auth_staff.host, ENV["PUBLIC_AUTH_STAFF_URL"],
           "auth.org.localhost",].compact,
  ) do
    scope(module: :org, as: :org) do
      root "roots#index"
      resource :dashboard, only: :show

      namespace(:well_known, path: ".well-known") do
        resource(:jwks, only: :show, path: "jwks.json", format: false)
      end

      # Deployment identifier endpoint.
      resource(:revision, only: :show, format: false)

      resource(:health, only: :show, format: false)
      namespace(:health) do
        resource(:liveness, only: :show, format: false)
        resource(:readiness, only: :show, format: false)
        resource(:startup, only: :show, format: false)
      end

      # Machine-readable health and revision. The literal ".json" is part of the path, not a Rails
      # format token (`format: false`), mirroring the `.well-known/jwks.json` precedent above.
      # These are JSON-only; the controllers answer 406 to any other `Accept`.
      namespace(:api) do
        namespace(:v0) do
          resource(:health, only: :show, path: "health.json", format: false)
          resource(:revision, only: :show, path: "revision.json", format: false)
        end
      end

      resources(:robots, only: :index, path: "robots.txt")
      resource(:sitemap, only: :show, path: "sitemap.xml")
      resource(:csp_violation_report, only: :create, path: "csp-violation-report")

      # PWA offline fallback. This is the route form Rails' own application generator emits, kept
      # verbatim except for the leading slash on the controller, which escapes the enclosing
      # `scope(module:)`. Approved exception to the resourceful routing rule; do not reshape it into
      # `resource`. See adr/pwa-offline-route-exception.md.
      get("service-worker", to: "/rails/pwa#service_worker", as: :pwa_service_worker)
      get("offline", to: "/rails/pwa#offline", as: :pwa_offline)

      # Staff management areas.
      resource :configuration, only: :show
      resources :accounts, only: :index
      resources :iam, only: :index
      resources :system, only: :index
      resources :audit, only: :index
      resources :support, only: :index
      resources :billing, only: :index

      # Canonical ceremony entrypoints and authed-out confirmation.
      namespace :sign do
        resource :registration, only: :show, path: "up", controller: :ups, as: :up
        resource :session, only: :show, path: "in", controller: :ins, as: :in
        resource :termination, only: %i(new edit create destroy), path: "out", controller: :outs, as: :out do
          resource :completion, only: :show, path: "complete", module: :outs
        end
      end

      namespace(:oidc) do
        resource(:authorization, only: :show)
        resource(:callback, only: :show)

        namespace(:backchannel) do
          resource(:logout, only: :create)
        end
      end

      # Public web API: cookie consent, theme.
      namespace :web do
        namespace :v0 do
          resource :theme, only: %i(show update)
          resource :cookie, only: %i(show update)
        end
      end

      # Edge compatibility API: token lifecycle management.
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :status, only: :show, path: "check", controller: :checks, as: :check
            resource :dbsc, only: :create
          end
        end
      end

      # Sign-up and sign-in ceremonies.
      namespace :sign do
        # Staff invitation auth-up.
        namespace :up do
          resources :invitations, only: %i(new create)
        end

        # Sign-in ceremony.
        namespace :in do
          resource :passkey, only: :new

          namespace :passkey do
            resource :options, only: :create
            resource :verification, only: :create
          end

          resource :secret, only: %i(new create)
          resource :session, only: %i(show update destroy)

          resource :guard, only: :show
          resource :check, only: :show

          resource :challenge, only: :show

          namespace :challenge do
            resource :passkey, only: %i(new create)
          end
        end
      end

      # OmniAuth-based Entra ID (Microsoft) sign-in.
      # See adr/org-entra-omniauth-strategy-migration.md.
      namespace(:social) do
        scope :entra, as: :entra, defaults: { provider: "entra" } do
          resource :session, only: %i(new create), controller: :sessions
        end

        # Non-resourceful exception: OmniAuth middleware owns these fixed
        # provider paths (see config/routes/auth.rb:146-160 for the app-side
        # equivalent, and config/initializers/omniauth.rb for the strategy).
        get(
          "entra/callback",
          to: "/auth/org/omniauth/omniauth_callbacks#omniauth",
          as: :entra_callback,
          defaults: { provider: "entra" },
        )

        get(
          "entra/failure",
          to: "/auth/org/omniauth/omniauth_callbacks#failure",
          as: :entra_failure,
        )
      end

      # Step-up verification.
      resource :verification, only: :show
      namespace :verification do
        resource :cancellation, only: :create
      end
      namespace :verification do
        resource :setup, only: :new
        resource :passkey, only: %i(new create)
      end

      # Settings and credential management.
      resource :settings, only: :show
      namespace :settings do
        resources :passkeys do
          resource :removal, only: :create
        end

        namespace :passkeys do
          resource :options, only: :create
          # Passkey (WebAuthn) assertion verification for settings-level re-auth.
          resource :verification, only: :create
        end

        resource :entra, only: %i(show edit create destroy)
      end
    end
  end
end
