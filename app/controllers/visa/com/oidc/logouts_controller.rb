# typed: false
# frozen_string_literal: true

module Visa
  module Com
    module Oidc
      class LogoutsController < Visa::Com::AuthorityController
        include ::VisaComOidcLogoutEndpoint

        AUTHENTICATION_MODE = :open

        layout -> { @render_surface_erb_layout ? "visa/com/application" : "visa/com/inertia" }
        declare_authentication_mode! :open

        public

        def show
          handle_oidc_end_session_request
        end

        def create
          handle_oidc_end_session_request
        end
      end
    end
  end
end
