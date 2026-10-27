# typed: false
# frozen_string_literal: true

module Visa
  module Org
    module Oidc
      module Logouts
        class ConfirmationsController < ::Visa::Org::AuthorityController
          include ::VisaOrgOidcLogoutEndpoint

          AUTHENTICATION_MODE = :open

          layout -> { @render_surface_erb_layout ? "visa/org/application" : "visa/org/inertia" }
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
