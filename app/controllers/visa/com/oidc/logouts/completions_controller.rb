# typed: false
# frozen_string_literal: true

module Visa
  module Com
    module Oidc
      module Logouts
        class CompletionsController < ::Visa::Com::AuthorityController
          include ::VisaComOidcLogoutEndpoint

          AUTHENTICATION_MODE = :open

          layout -> { @render_surface_erb_layout ? "visa/com/application" : "visa/com/inertia" }
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
