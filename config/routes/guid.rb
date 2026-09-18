# typed: false
# frozen_string_literal: true

# GUID owns the dedicated globally-unique-identifier service boundary.
# Public canonical host: guid.umaxica.net. Development host: guid.net.localhost.
scope module: :guid, as: :guid do
  constraints host: [ENV["PUBLIC_GUID_SERVICE_URL"], ENV["GUID_SERVICE_URL"], ENV["PRIVATE_GUID_SERVICE_URL"],
                     "guid.umaxica.net", "guid.net.localhost",].compact do
    scope module: :net, as: :net do
      root to: "roots#index"

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
          # FIXME: The public GUID lookup path is intentionally retained while its durable
          # persistence owner, opaque-ID lifecycle/uniqueness contract, and dedicated `net`
          # OpenAPI surface are decided. The current controller is a transport-safe 404 boundary;
          # do not add a model, issuance API, or guessed OpenAPI schema as part of route cleanup.
          resources :resources, only: :show, param: :guid
          resource :health, only: :show, path: "health.json", format: false
          resource :revision, only: :show, path: "revision.json", format: false
        end
      end
    end
  end
end
