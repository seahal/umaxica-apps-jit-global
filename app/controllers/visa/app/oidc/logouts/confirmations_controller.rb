# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Oidc
      module Logouts
        class ConfirmationsController < ::Visa::App::AuthorityController
          include ::VisaAppOidcLogoutEndpoint

          AUTHENTICATION_MODE = :open

          layout -> { @render_surface_erb_layout ? "visa/app/application" : "visa/app/inertia" }
          declare_authentication_mode! :open

          public

          def create
            confirm_oidc_end_session_logout
          end
        end
      end
    end
  end
end
