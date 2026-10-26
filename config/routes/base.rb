# typed: false
# frozen_string_literal: true

# Base owns identity, browser-RP and Rails control-plane surfaces. Visa owns the OIDC authority.
# Auth surfaces handle credential ceremonies and do not own RP authority.
scope(module: :base, as: :base) do
  # User authority gateway host. Hosts listed declaratively (DRY intentionally broken).
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).base_service.host, ENV["PUBLIC_BASE_SERVICE_URL"],
           "base.app.localhost",].compact,
  ) do
    scope(module: :app, as: :app) do
      root "roots#index"
      # Self-RP entry: GET renders a neutral form; POST starts the shared OIDC authorization flow.
      scope path: "sign", as: :sign do
        get "", to: "sign/entries#show", as: :show
        post "", to: "sign/entries#create", as: :create
        # D-153: one generic landing for expected abnormal endings of the sign flow.
        resource :interruption, only: :show, module: :sign
      end
      get "ceremony_bindings/:binding_ref/confirmation", to: "ceremony_binding_confirmations#show",
                                                         as: :ceremony_binding_confirmation
      post "ceremony_bindings/:binding_ref/confirmation", to: "ceremony_binding_confirmations#create"

      # Model Context Protocol endpoint. The MCP spec requires a single path serving POST; the
      # transport carries every protocol method in the JSON-RPC body, so one create action is the
      # whole endpoint.
      # Disabled pending an implementation review; see adr/mcp-endpoint-withdrawal.md.
      # resource :mcp, only: :create

      resource :welcome, only: :show
      resource :dashboard, only: :show, controller: :roots do
        # Streams the selected Avatar's private image; see adr/base-dashboard-avatar-image-delivery.md.
        resource :avatar_image, only: :show, controller: :dashboard_avatar_images
      end
      resource :selector, only: %i(show update)
      resource :switcher, only: %i(show update)
      resources :billings, only: :index
      resources :secrets, only: %i(index show new create edit update destroy)
      resources :secret_issuances, only: %i(show update destroy) do
        post :reattempt, on: :member
        resource :presentation, only: :create, controller: :secret_presentations
      end
      resources :groups, only: %i(index show create update destroy) do
        resources :avatar_memberships, controller: :group_avatar_memberships, only: %i(create update destroy)
      end
      resources :accounts, only: %i(index show)
      resources :organizations, only: %i(index show) do
        resources :memberships, module: :organizations
      end
      resource :preference, only: :show
      namespace :preference do
        resource :calendar, only: %i(edit update)
        resource :clock, only: %i(edit update)
        resource :cookie, only: %i(edit update)
        resource :currency, only: %i(edit update)
        resource :density, only: %i(edit update)
        resources :emails, only: :edit
        delete "emails/:id", to: "emails#destroy", as: :email
        post "emails/:id", to: "emails#create"
        resource :language, only: %i(edit update)
        resource :motion, only: %i(edit update)
        resource :pagination, only: %i(edit update)
        resource :region, only: %i(edit update)
        resource :customization, only: %i(edit destroy)
        resource :screen, only: %i(edit update)
        resource :theme, only: %i(edit update)
        resource :timezone, only: %i(edit update)
      end

      # Paths fixed by OIDC Discovery spec; resource names stay nouns.
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
          # R5-WU15 account/organization/membership owner API for the app Base Self-RP.
          # R5-WU12 account standing owner (Enforcement) for the Base Self-RP page /identity/standing.
          get("identity/standing", to: "identity/standings#show", as: :identity_standing)
          get("identity/selection", to: "identity/selections#show", as: :identity_selection)
          scope(path: "membership/app", as: :membership) do
            get("accounts", to: "membership/directory#accounts", as: :accounts)
            get("accounts/:ref", to: "membership/directory#account", as: :account)
            get("organizations", to: "membership/directory#organizations", as: :organizations)
            get("organizations/:ref", to: "membership/directory#organization", as: :organization)
            get("organizations/:organization_ref/memberships", to: "membership/directory#memberships", as: :memberships)
            get(
              "organizations/:organization_ref/memberships/:id", to: "membership/directory#membership",
                                                                 as: :membership,
            )
            post(
              "organizations/:organization_ref/memberships/authorization", to: "membership/directory#authorization",
                                                                           as: :membership_authorization,
            )
          end
          # R5-WU14 Avatar owner API for the app Base Self-RP (approved contract 2026-10-17).
          scope(path: "avatar/app", as: :avatar) do
            get("switcher", to: "avatar/switchers#show", as: :switcher)
            put("switcher", to: "avatar/switchers#update")
            get("dashboard-identity", to: "avatar/dashboard_identities#show", as: :dashboard_identity)
            get("selected-image", to: "avatar/selected_images#show", as: :selected_image)
            resources(:avatars, only: %i(index show create update), param: :avatar_ref, controller: "avatar/avatars")
            post(
              "avatars/:avatar_ref/:kind", to: "avatar/social_edges#create", as: :avatar_social_edge,
                                           constraints: { kind: /follows|blocks|mutes/ },
            )
            delete(
              "avatars/:avatar_ref/:kind", to: "avatar/social_edges#destroy",
                                           constraints: { kind: /follows|blocks|mutes/ },
            )
            post("ownership-transfers", to: "avatar/avatar_ownership_transfers#create", as: :ownership_transfers)
            post(
              "ownership-transfers/:ref/accept", to: "avatar/avatar_ownership_transfers#accept",
                                                 as: :accept_ownership_transfer,
            )
            post(
              "ownership-transfers/:ref/cancel", to: "avatar/avatar_ownership_transfers#cancel",
                                                 as: :cancel_ownership_transfer,
            )
            resources(:groups, only: %i(index show create update destroy), param: :ref, controller: "avatar/groups") do
              resources(
                :avatar_memberships, only: %i(create update destroy), param: :ref, path: "avatar-memberships",
                                     controller: "avatar/group_avatar_memberships",
              )
            end
          end
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

      # Base owns the post-authentication sign-out confirmation and completion resources.
      scope path: :sign do
        resource :termination, path: "out", controller: :sign_outs, as: :sign_out,
                               only: %i(show new edit create)
        resource :out_completion, only: :show, path: "out/completion",
                                  controller: :sign_outs, as: :sign_out_completion
      end

      # Base is a first-party browser RP on this host; Visa is the OIDC authority.

      # The Base RP callback and back-channel logout receiver stay on this host.
      post("sign/out/purge", to: "sign/cookie_purges#create", as: :sign_out_purge)
      namespace(:oidc) do
        resource(:callback, only: :show)
        # R5-WU10 server-to-server OIDC Back-Channel Logout receiver for this RP cell.
        resources(:closures, only: :create)
      end

      # Browser preference API for this host's own chrome controls (theme, cookie consent). Same
      # contract as Core: see adr/preference-browser-transport-family-capability.md. GET + PATCH only:
      # `resource ... only: :update` would also map PUT (adr/api-route-vocabulary-consolidation.md,
      # 2026-10-02 amendment).
      namespace :api do
        namespace :v0 do
          namespace :preferences do
            get :cookie, to: "cookies#show"
            patch :cookie, to: "cookies#update"
            get :theme, to: "themes#show"
            patch :theme, to: "themes#update"
          end
        end
      end

      namespace(:social) do
        # Base-side ceremony endpoint: the continuation hands the browser to the Auth host. Sign-up
        # finalizes in Auth (adr/sign-up-finalization-in-auth.md).
        namespace :authentication do
          resource :continuation, only: :create
        end

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

        # There is no ceremony start route here. Base starts a social ceremony
        # through the continuation endpoint above, which issues a grant and
        # hands the browser to the Auth host's POST-only endpoint with a 307.
        # A GET start page would be login CSRF (CVE-2015-9284).
      end

      # Step-up verification.
      resource :verification, only: %i(show create)
      namespace :verification do
        resource :cancellation, only: %i(show create)
        resource :completion, only: %i(show create)
        # Choice of a first authenticator. GET shows the methods; POST starts one bootstrap.
        resource :setup, only: %i(show create)
      end

      resource :identity, only: :show
      # User-facing sessions have the canonical top-level resource path. The identity namespace
      # remains as a compatibility route for existing links while callers migrate.
      resource :other_sessions, path: "sessions/other", controller: "identity/revocations/others", only: :destroy
      resources :sessions, controller: "identity/sessions", only: %i(index show destroy)
      resources :avatars, only: %i(index show new edit create update) do
        resource :follow, controller: "avatars/follows", only: %i(create destroy)
        resource :block, controller: "avatars/blocks", only: %i(create destroy)
        resource :mute, controller: "avatars/mutes", only: %i(create destroy)
      end
      post "avatar_ownership_transfers", to: "avatar_ownership_transfers#create", as: :avatar_ownership_transfers
      post "avatar_ownership_transfers/:id/accept", to: "avatar_ownership_transfers#accept",
                                                    as: :accept_avatar_ownership_transfer
      post "avatar_ownership_transfers/:id/cancel", to: "avatar_ownership_transfers#cancel",
                                                    as: :cancel_avatar_ownership_transfer

      namespace :identity do
        resource :standing, only: :show
        resources :passkeys, only: %i(index show new create update destroy)
        resources :totps, only: %i(index show new create update destroy)
        resource :recovery, only: :show do
          resource :completion, only: :create, module: :recovery
        end
        namespace :recovery do
          resource :session, only: %i(new create)
          resources :appeals, only: :create
        end
        namespace :mfa do
          resource :reset, only: :show
          resource :challenge, only: %i(show update)
        end

        namespace :emails do
          resource :registration, only: %i(new create edit update) do
            resource :redelivery, only: :create
          end
        end

        resources :emails, only: %i(index edit update destroy)

        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end

        resources :telephones, only: %i(index new create edit destroy)

        resource :birthdate, only: :show

        resources :sessions, only: %i(index show destroy)
        resource :revocation, only: :destroy, path: "other_sessions", controller: "revocations/others",
                              as: :other_sessions

        resources :activities, only: :index

        resource :withdrawal, only: %i(new edit create update destroy)
        namespace :withdrawal do
          # DELETE ends the withdrawal ceremony session.
          resource :session, only: %i(new create destroy)
        end
        namespace :privacy do
          resource :erasure, only: %i(new create)
          namespace :erasure do
            resource :status, only: :show
          end
        end
      end
    end
  end

  # Corporate authority gateway host.
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).base_corporate.host,
           ENV["PUBLIC_BASE_CORPORATE_URL"], "base.com.localhost",].compact,
  ) do
    scope(module: :com, as: :com) do
      root "roots#index"
      # Self-RP entry: GET renders a neutral form; POST starts the shared OIDC authorization flow.
      scope path: "sign", as: :sign do
        get "", to: "sign/entries#show", as: :show
        post "", to: "sign/entries#create", as: :create
        # D-153: one generic landing for expected abnormal endings of the sign flow.
        resource :interruption, only: :show, module: :sign
      end
      get "ceremony_bindings/:binding_ref/confirmation", to: "ceremony_binding_confirmations#show",
                                                         as: :ceremony_binding_confirmation
      post "ceremony_bindings/:binding_ref/confirmation", to: "ceremony_binding_confirmations#create"

      # Model Context Protocol endpoint. The MCP spec requires a single path serving POST; the
      # transport carries every protocol method in the JSON-RPC body, so one create action is the
      # whole endpoint.
      # Disabled pending an implementation review; see adr/mcp-endpoint-withdrawal.md.
      # resource :mcp, only: :create

      resource :welcome, only: :show
      resource :dashboard, only: :show, controller: :roots
      resource :selector, only: %i(show update)
      resource :switcher, only: %i(show update)
      resources :accounts, only: %i(index show)
      resources :organizations, only: %i(index show) do
        resources :memberships, module: :organizations
      end
      resource :preference, only: :show

      namespace :preference do
        resource :calendar, only: %i(edit update)
        resource :clock, only: %i(edit update)
        resource :cookie, only: %i(edit update)
        resource :currency, only: %i(edit update)
        resource :density, only: %i(edit update)
        resources :emails, only: :edit
        delete "emails/:id", to: "emails#destroy", as: :email
        post "emails/:id", to: "emails#create"
        resource :language, only: %i(edit update)
        resource :motion, only: %i(edit update)
        resource :pagination, only: %i(edit update)
        resource :region, only: %i(edit update)
        resource :customization, only: %i(edit destroy)
        resource :screen, only: %i(edit update)
        resource :theme, only: %i(edit update)
        resource :timezone, only: %i(edit update)
      end

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
          # R5-WU15 account/organization/membership owner API for the com Base Self-RP.
          # R5-WU12 account standing owner (Enforcement) for the Base Self-RP page /identity/standing.
          get("identity/standing", to: "identity/standings#show", as: :identity_standing)
          get("identity/selection", to: "identity/selections#show", as: :identity_selection)
          scope(path: "membership/com", as: :membership) do
            get("accounts", to: "membership/directory#accounts", as: :accounts)
            get("accounts/:ref", to: "membership/directory#account", as: :account)
            get("organizations", to: "membership/directory#organizations", as: :organizations)
            get("organizations/:ref", to: "membership/directory#organization", as: :organization)
            get("organizations/:organization_ref/memberships", to: "membership/directory#memberships", as: :memberships)
            get(
              "organizations/:organization_ref/memberships/:id", to: "membership/directory#membership",
                                                                 as: :membership,
            )
            post(
              "organizations/:organization_ref/memberships/authorization", to: "membership/directory#authorization",
                                                                           as: :membership_authorization,
            )
          end
          # R5-WU14 context switcher for the com Base Self-RP (approved contract 2026-10-17).
          scope(path: "avatar/com", as: :avatar) do
            get("dashboard-identity", to: "avatar/dashboard_identities#show", as: :dashboard_identity)
            get("switcher", to: "avatar/switchers#show", as: :switcher)
            put("switcher", to: "avatar/switchers#update")
          end
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

      # Base owns the post-authentication sign-out confirmation and completion resources.
      scope path: :sign do
        resource :termination, path: "out", controller: :sign_outs, as: :sign_out,
                               only: %i(show new edit create)
        resource :out_completion, only: :show, path: "out/completion",
                                  controller: :sign_outs, as: :sign_out_completion
      end

      # Base is a first-party browser RP on this host; Visa is the OIDC authority.

      post("sign/out/purge", to: "sign/cookie_purges#create", as: :sign_out_purge)
      namespace(:oidc) do
        resource(:callback, only: :show)
        # R5-WU10 server-to-server OIDC Back-Channel Logout receiver for this RP cell.
        resources(:closures, only: :create)
      end

      # Browser preference API for this host's own chrome controls (theme, cookie consent). Same
      # contract as Core: see adr/preference-browser-transport-family-capability.md. GET + PATCH only:
      # `resource ... only: :update` would also map PUT (adr/api-route-vocabulary-consolidation.md,
      # 2026-10-02 amendment).
      namespace :api do
        namespace :v0 do
          namespace :preferences do
            get :cookie, to: "cookies#show"
            patch :cookie, to: "cookies#update"
            get :theme, to: "themes#show"
            patch :theme, to: "themes#update"
          end
        end
      end

      # Step-up verification.
      resource :verification, only: %i(show create)
      namespace :verification do
        resource :cancellation, only: %i(show create)
        resource :completion, only: %i(show create)
        resource :setup, only: %i(show create)
      end

      resource :identity, only: :show
      # User-facing sessions have the canonical top-level resource path. The identity namespace
      # remains as a compatibility route for existing links while callers migrate.
      resource :other_sessions, path: "sessions/other", controller: "identity/revocations/others", only: :destroy
      resources :sessions, controller: "identity/sessions", only: %i(index show destroy)
      namespace :identity do
        resource :standing, only: :show
        resource :recovery_secret, only: :show, path: "recovery-secret"
        resources :passkeys, only: %i(index show new create update destroy)
        namespace :mfa do
          resource :reset, only: :show
          resource :challenge, only: %i(show update)
        end
        resource :recovery, only: :show do
          resource :completion, only: :create, module: :recovery
        end
        namespace :recovery do
          resource :session, only: %i(new create)
          resources :appeals, only: :create
        end
        namespace :emails do
          resource :registration, only: %i(new create edit update)
        end
        resources :emails, only: %i(index edit update destroy)

        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end
        resources :telephones, only: %i(index new create edit destroy)

        resource :birthdate, only: :show

        resources :secrets,
                  controller: :secret_credentials,
                  only: %i(index show new edit create update destroy) do
          resource :rotation, only: :create
          resource :removal, only: :create
        end
        resources :sessions, only: %i(index show destroy)
        resource :revocation, only: :destroy, path: "other_sessions", controller: "revocations/others",
                              as: :other_sessions

        resources :activities, only: :index
        resource :withdrawal, only: %i(new edit create update destroy)
        namespace :withdrawal do
          # DELETE ends the withdrawal ceremony session.
          resource :session, only: %i(new create destroy)
        end
        namespace :privacy do
          resource :erasure, only: %i(new create)
          namespace :erasure do
            resource :status, only: :show
          end
        end
      end
    end
  end

  # Staff authority gateway host.
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host, ENV["PUBLIC_BASE_STAFF_URL"],
           "base.org.localhost",].compact,
  ) do
    scope(module: :org, as: :org) do
      root "roots#index"
      # Self-RP entry: GET renders a neutral form; POST starts the shared OIDC authorization flow.
      scope path: "sign", as: :sign do
        get "", to: "sign/entries#show", as: :show
        post "", to: "sign/entries#create", as: :create
        # D-153: one generic landing for expected abnormal endings of the sign flow.
        resource :interruption, only: :show, module: :sign
      end
      get "ceremony_bindings/:binding_ref/confirmation", to: "ceremony_binding_confirmations#show",
                                                         as: :ceremony_binding_confirmation
      post "ceremony_bindings/:binding_ref/confirmation", to: "ceremony_binding_confirmations#create"

      # Model Context Protocol endpoint. The MCP spec requires a single path serving POST; the
      # transport carries every protocol method in the JSON-RPC body, so one create action is the
      # whole endpoint.
      # Disabled pending an implementation review; see adr/mcp-endpoint-withdrawal.md.
      # resource :mcp, only: :create

      resource :welcome, only: :show
      resource :dashboard, only: :show, controller: :roots do
        # Streams the selected Avatar's private image; see adr/base-dashboard-avatar-image-delivery.md.
        resource :avatar_image, only: :show, controller: :dashboard_avatar_images
      end
      resource :selector, only: %i(show update)
      resource :switcher, only: %i(show update)
      resource :preference, only: :show
      resource :avatar, only: %i(show edit update destroy)
      post "avatar_ownership_transfers", to: "avatar_ownership_transfers#create", as: :avatar_ownership_transfers
      post "avatar_ownership_transfers/:id/accept", to: "avatar_ownership_transfers#accept",
                                                    as: :accept_avatar_ownership_transfer
      post "avatar_ownership_transfers/:id/cancel", to: "avatar_ownership_transfers#cancel",
                                                    as: :cancel_avatar_ownership_transfer
      resources :organizations, only: %i(index show) do
        # Org memberships are read-only: who may add, change, or end an Agent's membership in a
        # Bureau is not yet specified (adr/operator-capability-authorization.md, Not provided).
        resources :memberships, only: %i(index show), module: :organizations
      end

      namespace :preference do
        resource :calendar, only: %i(edit update)
        resource :clock, only: %i(edit update)
        resource :cookie, only: %i(edit update)
        resource :currency, only: %i(edit update)
        resource :density, only: %i(edit update)
        resources :emails, only: :edit
        delete "emails/:id", to: "emails#destroy", as: :email
        post "emails/:id", to: "emails#create"
        resource :language, only: %i(edit update)
        resource :motion, only: %i(edit update)
        resource :pagination, only: %i(edit update)
        resource :region, only: %i(edit update)
        resource :customization, only: %i(edit destroy)
        resource :screen, only: %i(edit update)
        resource :theme, only: %i(edit update)
        resource :timezone, only: %i(edit update)
      end

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
          # R5-WU15 account/organization/membership owner API for the org Base Self-RP.
          # R5-WU12 account standing owner (Enforcement) for the Base Self-RP page /identity/standing.
          get("identity/standing", to: "identity/standings#show", as: :identity_standing)
          get("identity/selection", to: "identity/selections#show", as: :identity_selection)
          scope(path: "membership/org", as: :membership) do
            get("accounts", to: "membership/directory#accounts", as: :accounts)
            get("accounts/:ref", to: "membership/directory#account", as: :account)
            get("organizations", to: "membership/directory#organizations", as: :organizations)
            get("organizations/:ref", to: "membership/directory#organization", as: :organization)
            get("organizations/:organization_ref/memberships", to: "membership/directory#memberships", as: :memberships)
            get(
              "organizations/:organization_ref/memberships/:id", to: "membership/directory#membership",
                                                                 as: :membership,
            )
            post(
              "organizations/:organization_ref/memberships/authorization", to: "membership/directory#authorization",
                                                                           as: :membership_authorization,
            )
          end
          # R5-WU14 Avatar owner API for the org Base Self-RP (approved contract 2026-10-17).
          # R5-WU12 Support owner for app Client / com Visitor administration.
          # R5-WU17 Support landing owner for the Base Self-RP page /support.
          get("support", to: "support/areas#index", as: :support_areas)
          scope(path: "support/:realm", as: :support, constraints: { realm: /app|com/ }) do
            get("accounts", to: "support/accounts#index", as: :accounts)
            get("accounts/:ref", to: "support/accounts#show", as: :account)
            get("accounts/:ref/revocation-screen", to: "support/accounts#revocation_screen", as: :revocation_screen)
            post("accounts/:ref/revocations", to: "support/accounts#revoke", as: :revocations)
            get("accounts/:ref/revocations/:event_uuid", to: "support/accounts#revocation", as: :revocation)
          end
          # R5-WU12 Enforcement owner: same resource shape as the Base Self-RP pages it serves; the org
          # realm stays routed so its policy can deny it exactly as before.
          scope(path: "support/:realm", as: :support_enforcement, constraints: { realm: /app|com|org/ }) do
            resources(:enforcement_cases, only: %i(index show new create), controller: "support/enforcement_cases") do
              resource(:approval, only: %i(new create), controller: "support/enforcement_cases/approvals")
              resource(:release, only: %i(new create), controller: "support/enforcement_cases/releases")
              resource(:appeal_review, only: %i(new create), controller: "support/enforcement_cases/appeal_reviews")
            end
          end
          # R5-WU12 IAM capability grants owner for the org Base Self-RP.
          scope(path: "iam", as: :iam) do
            get("grants", to: "iam/grants#index", as: :grants)
            get("grant-screen", to: "iam/grants#screen", as: :grant_screen)
            post("grants", to: "iam/grants#create")
            get("grants/:ref", to: "iam/grants#show", as: :grant)
            post("grants/:ref/revocation", to: "iam/grants#revoke", as: :grant_revocation)
          end
          scope(path: "avatar/org", as: :avatar) do
            get("dashboard-identity", to: "avatar/dashboard_identities#show", as: :dashboard_identity)
            get("switcher", to: "avatar/switchers#show", as: :switcher)
            put("switcher", to: "avatar/switchers#update")
            get("selected-avatar", to: "avatar/selected_avatars#show", as: :selected_avatar)
            patch("selected-avatar", to: "avatar/selected_avatars#update")
            delete("selected-avatar", to: "avatar/selected_avatars#destroy")
            get("selected-image", to: "avatar/selected_images#show", as: :selected_image)
            post("ownership-transfers", to: "avatar/avatar_ownership_transfers#create", as: :ownership_transfers)
            post(
              "ownership-transfers/:ref/accept", to: "avatar/avatar_ownership_transfers#accept",
                                                 as: :accept_ownership_transfer,
            )
            post(
              "ownership-transfers/:ref/cancel", to: "avatar/avatar_ownership_transfers#cancel",
                                                 as: :cancel_ownership_transfer,
            )
          end
          # R5-WU11 org-authority Tech capability decision for the tech-org-ww RP (server-to-server).
          resource(
            :tech_capability_check, only: :create, path: "tech-capability-checks",
                                    controller: :tech_capability_checks,
          )
          # R5-WU13 Publishing authority for the Edit RP; fixed cells, scoped public references.
          scope(
            path: "publishing/:surface/:audience", as: :publishing,
            constraints: { surface: /docs|help|info|news/, audience: /app|com|org/ },
          ) do
            resources(
              :entries, only: %i(index show create update), param: :entry_ref,
                        controller: "publishing/entries",
            ) do
              resources(
                :publications, only: %i(create destroy), param: :publication_ref, controller: "publishing/publications",
              )
              resource(:archive, only: %i(create destroy), controller: "publishing/archives")
            end
          end
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
      resources :accounts, only: %i(index show)
      resources :iam, only: :index
      # adr/operator-capability-authorization.md, IAM: capability grants. A revocation is its own
      # noun resource; `new` is the Step-Up-gated confirmation page for each mutation.
      namespace :iam do
        resources :grants, only: %i(index show new create) do
          resource :revocation, only: %i(new create), module: :grants
        end
      end
      resources :system, only: :index
      resources :audit, only: :index
      resources :support, only: :index
      namespace :support do
        # adr/operator-capability-authorization.md, Support: Clients are the app realm and Visitors
        # the com realm, fixed by the resource name; no parameter selects the target class. Each
        # session revocation is a recorded operation (`show` is its result).
        resources :clients, only: %i(index show) do
          resources :revocations, only: %i(new create show), module: :clients
        end
        resources :visitors, only: %i(index show) do
          resources :revocations, only: %i(new create show), module: :visitors
        end

        # adr/unified-enforcement.md, Approval: realm-scoped noun resources, per
        # .agents/harnesses/rules/generic/routing.mdc (no verb actions such as
        # `approve`/`release`; each is its own nested resource). `new` pages are the Step-Up-gated
        # confirmation screens. The org realm stays routed but every policy rule denies it: no
        # capability for disciplining operators is defined.
        %i(app com org).each do |enforcement_realm|
          scope(path: enforcement_realm, as: enforcement_realm, defaults: { realm: enforcement_realm }) do
            resources :enforcement_cases, only: %i(index show new create) do
              resource :approval, only: %i(new create), controller: "enforcement_cases/approvals"
              resource :release, only: %i(new create), controller: "enforcement_cases/releases"
              resource :appeal_review, only: %i(new create), controller: "enforcement_cases/appeal_reviews"
            end
          end
        end
      end
      resources :billing, only: :index

      # Base owns the post-authentication sign-out confirmation and completion resources.
      scope path: :sign do
        resource :termination, path: "out", controller: :sign_outs, as: :sign_out,
                               only: %i(show new edit create)
        resource :out_completion, only: :show, path: "out/completion",
                                  controller: :sign_outs, as: :sign_out_completion
      end

      # Base is a first-party browser RP on this host; Visa is the OIDC authority.

      post("sign/out/purge", to: "sign/cookie_purges#create", as: :sign_out_purge)
      namespace(:oidc) do
        resource(:callback, only: :show)
        # R5-WU10 server-to-server OIDC Back-Channel Logout receiver for this RP cell.
        resources(:closures, only: :create)
      end

      # Browser preference API for this host's own chrome controls (theme, cookie consent). Same
      # contract as Core: see adr/preference-browser-transport-family-capability.md. GET + PATCH only:
      # `resource ... only: :update` would also map PUT (adr/api-route-vocabulary-consolidation.md,
      # 2026-10-02 amendment).
      namespace :api do
        namespace :v0 do
          namespace :preferences do
            get :cookie, to: "cookies#show"
            patch :cookie, to: "cookies#update"
            get :theme, to: "themes#show"
            patch :theme, to: "themes#update"
          end
        end
      end

      # Step-up verification.
      resource :verification, only: %i(show create)
      namespace :verification do
        resource :cancellation, only: %i(show create)
        resource :completion, only: %i(show create)
        resource :setup, only: %i(show create)
      end

      resource :identity, only: :show
      # User-facing sessions have the canonical top-level resource path. The identity namespace
      # remains as a compatibility route for existing links while callers migrate.
      resource :other_sessions, path: "sessions/other", controller: "identity/revocations/others", only: :destroy
      resources :sessions, controller: "identity/sessions", only: %i(index show destroy)
      namespace :identity do
        resource :standing, only: :show
        resources :passkeys, only: %i(index show new create update destroy)
        namespace :mfa do
          resource :reset, only: :show
        end
        namespace :emails do
          resource :registration, only: %i(new create edit update)
        end
        resources :emails, only: %i(index edit update destroy)

        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end
        resources :telephones, only: %i(index new create edit destroy)

        resource :birthdate, only: :show

        resources :secrets,
                  controller: :secret_credentials,
                  only: %i(index show new edit create update destroy) do
          resource :rotation, only: :create
          resource :removal, only: :create
        end
        resources :sessions, only: %i(index show destroy)
        resource :other_sessions, only: :destroy, controller: "revocations/others"

        resources :activities, only: :index
        resource :withdrawal, only: :show
      end
    end
  end

  constraints(host: [ENV["PRIVATE_BASE_NETWORK_URL"], "base.net.localhost"].compact) do
    scope(module: :net, as: :network) do
      # Thin landing endpoint.
      root(to: "roots#index")

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

      resource(:csp_violation_report, only: :create, path: "csp-violation-report")
    end
  end

  constraints(
    host: [ENV["PUBLIC_BASE_DEVELOPER_URL"], ENV["PRIVATE_BASE_DEVELOPER_URL"],
           "base.dev.localhost",].compact,
  ) do
    scope(module: :dev, as: :developer) do
      # Thin landing endpoint.
      root(to: "roots#index")

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

      resource(:csp_violation_report, only: :create, path: "csp-violation-report")
    end
  end
end
