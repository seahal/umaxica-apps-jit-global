# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Sign
      module Out
        class CompletionsController < Palm::App::ApplicationController
          include ::AuthenticationLogoutable
          include ::SignOutNotice
          include ::OidcRpLogoutLauncher
          include ::SignOutClearSiteData

          AUTHENTICATION_MODE = :open
          helper_method :sign_out_completed_description, :sign_out_confirmation_form_path

          public

          def show
            complete_oidc_rp_logout!
          end

          private

          def sign_out_confirmation_form_path
            palm_app_sign_out_completion_path
          end

          def sign_out_post_path(**options)
            palm_app_sign_out_completion_path(**sign_out_route_params, **options.compact)
          end

          # The durable logout challenge authorizes origin cleanup after parent revocation; refreshing
          # here would only fail and clear the Palm RP cookies.
          def browser_rp_unsafe_request_refresh_enabled?
            false
          end
        end
      end
    end
  end
end
