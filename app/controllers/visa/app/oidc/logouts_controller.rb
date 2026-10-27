# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Oidc
      class LogoutsController < Visa::App::AuthorityController
        include ::VisaAppOidcLogoutEndpoint

        AUTHENTICATION_MODE = :open

        layout -> { @render_surface_erb_layout ? "visa/app/application" : "visa/app/inertia" }
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
