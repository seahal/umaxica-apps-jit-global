# typed: false
# frozen_string_literal: true

# Tech owns the global operator tools surface.
private_tech_staff_url = ENV["PRIVATE_TECH_STAFF_URL"]
tech_staff_hosts = [Rails.configuration.x.boot_config.fetch(:hosts).tech_staff.host, "tech.org.localhost"]
tech_staff_hosts << private_tech_staff_url if private_tech_staff_url.present?

scope module: :tech, as: :tech do
  constraints host: tech_staff_hosts do
    scope module: :org, as: :org do
      root to: "roots#index"

      resource :dashboard, only: :show
      resource :revision, only: :show, format: false
      resource :health, only: :show, format: false
      namespace :health do
        resource :liveness, only: :show, format: false
        resource :readiness, only: :show, format: false
        resource :startup, only: :show, format: false
      end

      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      namespace :api do
        namespace :v0 do
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end

      # R5-WU16 matching-session RP cookie purge after OP logout.
      post("sign/out/purge", to: "sign/cookie_purges#create", as: :sign_out_purge)
      namespace :oidc do
        resource :callback, only: :show
        # R5-WU10 server-to-server OIDC Back-Channel Logout receiver for this RP cell.
        resources :closures, only: :create
      end

      scope path: "sign", as: :sign do
        get "", to: "sign/entries#show", as: :show
        post "", to: "sign/entries#create", as: :create
        # D-153: one generic landing for expected abnormal endings of the sign flow.
        resource :interruption, only: :show, module: :sign
      end

      namespace :sign do
        resource :out, only: %i(show create), controller: :outs
        resource :out_completion, only: :show, path: "out/completion",
                                  controller: "out/completions"
      end
    end
  end
end
