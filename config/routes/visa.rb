# typed: false
# frozen_string_literal: true

# Visa is the OpenID Provider surface. It has no Base browser-RP routes and
# each realm is constrained to its own Visa host.
scope(module: :visa, as: :visa) do
  {
    app: :service,
    com: :corporate,
    org: :staff,
  }.each do |surface_namespace, realm|
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    origin = hosts.public_send("visa_#{realm}")
    public_env = "PUBLIC_VISA_#{realm.to_s.upcase}_URL"
    local_host = "visa.#{surface_namespace}.localhost"

    constraints(host: [origin&.host, ENV[public_env], local_host].compact) do
      scope(module: surface_namespace, as: surface_namespace) do
        # Public root exception: adr/rails-routing-resourceful-policy.md, Visa public roots.
        root "roots#index"

        resource(
          :ceremony_binding_confirmation,
          only: :show,
          path: "ceremony_bindings/:binding_ref/confirmation",
          controller: :ceremony_binding_confirmations,
        )

        namespace(:well_known, path: ".well-known") do
          resource(
            :openid_configuration,
            only: :show, path: "openid-configuration", controller: :discoveries,
            format: false,
          )
          resource(:jwks, only: :show, path: "jwks.json", format: false)
        end

        resource(:health, only: :show, format: false)
        namespace(:health) do
          resource(:liveness, only: :show, format: false)
          resource(:readiness, only: :show, format: false)
          resource(:startup, only: :show, format: false)
        end
        namespace(:api) do
          namespace(:v0) do
            resource(:health, only: :show, path: "health.json", format: false)
            resource(:revision, only: :show, path: "revision.json", format: false)
          end
        end
        resource(:revision, only: :show, format: false)
        resources(:robots, only: :index, path: "robots.txt")
        resource(:csp_violation_report, only: :create, path: "csp-violation-report")

        namespace(:oauth) do
          resource(:authorization, only: %i(show create), path: "authorize", controller: :authorizations)
          resource(:token, only: :create, controller: :tokens)
          resource(:userinfo, only: %i(show create), controller: :userinfos)
          resource(:revocation, only: :create, path: "revoke", controller: :revocations)
        end

        namespace(:oidc) do
          resource(:logout, only: %i(show create), controller: :logouts)
          scope(module: :logouts, path: :logout, as: :logout) do
            resource :confirmation, only: :create
          end
          resource(:result, only: :show, controller: :results)
          resource(:cancellation, only: :show, controller: :cancellations)
          if surface_namespace != :org
            resource(:switch, only: :show, controller: :switches)
          end
        end

        scope path: :sign do
          resource :bye, only: %i(show create), path: "bye", controller: :sign_byes, as: :sign_bye
        end

        namespace :sign do
          namespace :in do
            resource :limitation, only: %i(show update destroy), controller: :limitations
            post "limitation", to: "limitations#update", as: :limitation_continue
          end
        end

        namespace :edge do
          namespace :v0 do
            namespace :token do
              resource :status, only: :show, path: "check", controller: :checks, as: :check
              resource :dbsc, only: :create
              resource :refresh, only: :create
            end
          end
        end
      end
    end
  end
end
