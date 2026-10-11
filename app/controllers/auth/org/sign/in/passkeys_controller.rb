# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        # GET /sign/in/passkey/new
        #
        # Second stage of Normal org sign-in. Entra ID has already identified
        # the Operator, so this page no longer asks who is signing in: the
        # pending Entra transaction names them, and the ceremony below reads the
        # Operator from there rather than from anything the browser sends.
        #
        # Without that transaction there is nothing to continue, so the page
        # sends the visitor back to the sign-in entry instead of offering a
        # standalone passkey sign-in. Passkey sign-in without Entra is Emergency
        # Access, which is its own ceremony under /sign/in/emergency.
        class PasskeysController < ::Auth::Org::ApplicationController
          include MinimumResponseBudget
          include ::CloudflareTurnstile
          include ::TurnstilePageProps
          include ::SurfaceInertiaPage
          include ::OrgNormalSignInTransaction
          include ::AuthenticationModeSwitchGuard

          AUTHENTICATION_MODE = :guest

          before_action :start_minimum_response_budget
          after_action :enforce_minimum_response_budget
          before_action :require_org_normal_sign_in_transaction!

          def new
            render inertia: true, props: passkey_sign_in_props
          end

          private

          def require_org_normal_sign_in_transaction!
            return if org_normal_sign_in_operator.present?

            clear_org_normal_sign_in_transaction!
            redirect_to(
              auth_org_sign_in_path(ri: current_region_identifier),
              status: :see_other,
            )
          end

          def passkey_sign_in_props
            pt = signed_pt_param
            region = current_region_identifier

            {
              title: t("sign.org.authentication.passkey.new.page_title"),
              description: t("sign.org.authentication.passkey.new.description"),
              panel: {
                options_url: auth_org_sign_in_passkey_options_path(pt: pt, ri: region),
                verification_url: auth_org_sign_in_passkey_verification_path(pt: pt, ri: region),
                region: region.to_s,
                # The Operator is fixed by the Entra transaction, so the panel
                # submits no identifier and renders no field for one.
                identifier_param: nil,
                turnstile_site_key: turnstile_site_key(:CLOUDFLARE_TURNSTILE_SITE_STEALTH_KEY),
                turnstile_error_message: t("turnstile_error"),
                field: nil,
                submit_label: t("sign.org.authentication.passkey.new.submit"),
              },
              secret_link: {
                label: t("sign.org.authentication.passkey.new.secret_credential"),
                href: new_auth_org_sign_in_secret_path(pt: pt, ri: region),
              },
              back_link: {
                label: t("sign.org.authentication.new.back"),
                href: auth_org_sign_in_path(pt: pt, ri: region),
              },
            }
          end

          def minimum_response_budget_enabled?
            false
          end
        end
      end
    end
  end
end
