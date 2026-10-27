# typed: false
# frozen_string_literal: true

module Visa
  module Org
    module Oidc
      module Logouts
        class CompletionsController < ::Visa::Org::AuthorityController
          include ::VisaOrgOidcLogoutEndpoint

          AUTHENTICATION_MODE = :open

          layout -> { @render_surface_erb_layout ? "visa/org/application" : "visa/org/inertia" }
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
