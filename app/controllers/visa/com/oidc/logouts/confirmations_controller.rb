# typed: false
# frozen_string_literal: true

module Visa
  module Com
    module Oidc
      module Logouts
        class ConfirmationsController < ::Visa::Com::AuthorityController
          include ::VisaComOidcLogoutEndpoint

          AUTHENTICATION_MODE = :open

          layout -> { @render_surface_erb_layout ? "visa/com/application" : "visa/com/inertia" }
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
