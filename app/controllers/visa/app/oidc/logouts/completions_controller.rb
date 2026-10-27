# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Oidc
      module Logouts
        class CompletionsController < ::Visa::App::AuthorityController
          include ::VisaAppOidcLogoutEndpoint

          AUTHENTICATION_MODE = :open

          layout -> { @render_surface_erb_layout ? "visa/app/application" : "visa/app/inertia" }
          declare_authentication_mode! :open

          public

          def show
            render_oidc_logout_completion
          end
        end
      end
    end
  end
end
