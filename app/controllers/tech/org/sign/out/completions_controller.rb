# typed: false
# frozen_string_literal: true

module Tech
  module Org
    module Sign
      module Out
        class CompletionsController < Tech::Org::ApplicationController
          include ::AuthenticationLogoutable
          include ::SignOutNotice
          include ::OidcRpLogoutLauncher
          include ::SignOutClearSiteData

          # OidcRpLogoutLauncher prepends its region callback; restore the policy header first.
          prepend_before_action :apply_default_no_store

          AUTHENTICATION_MODE = :open
          helper_method :sign_out_completed_description, :sign_out_confirmation_form_path

          public

          def show
            complete_oidc_rp_logout!
          end

          private

          def sign_out_confirmation_form_path
            tech_org_sign_out_completion_path
          end

          def sign_out_post_path(**options)
            tech_org_sign_out_completion_path(**sign_out_route_params, **options.compact)
          end

          # The durable logout challenge authorizes this continuation after the parent token is
          # revoked; a refresh attempt would only fail and clear the origin's RP cookies.
          def browser_rp_unsafe_request_refresh_enabled?
            false
          end
        end
      end
    end
  end
end
