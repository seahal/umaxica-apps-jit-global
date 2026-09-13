# typed: false
# frozen_string_literal: true

# Edit owns the staff Publishing management surface.
# Public canonical host: edit.umaxica.org. Development host: edit.org.localhost.
scope module: :edit, as: :edit do
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).edit_staff.host,
                     ENV["PUBLIC_EDIT_STAFF_URL"], ENV["PRIVATE_EDIT_STAFF_URL"],
                     "edit.umaxica.org", "edit.org.localhost",].compact do
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

      # Staff Publishing CMS. The URL is surface and audience only; locale is not a
      # path segment. Each cell maps to every Edition with that surface and audience.
      resource :publishing, only: [], module: :publishing do
        publishing_audiences = %i(app com org)
        %i(info docs news help).each do |publishing_surface|
          resource publishing_surface, only: [], module: publishing_surface do
            publishing_audiences.each do |publishing_audience|
              resource publishing_audience, only: [], module: publishing_audience do
                resources :entries, only: %i(index new create show edit update) do
                  scope module: :entries do
                    resources :publications, only: %i(create destroy)
                    resource :archive, only: %i(create destroy)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
