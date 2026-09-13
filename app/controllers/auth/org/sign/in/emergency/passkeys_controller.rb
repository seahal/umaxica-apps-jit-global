# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        module Emergency
          # Entry page for Emergency Access (Restricted Mode).
          #
          # Emergency sign-in is Passkey-only and does not involve Entra ID. It
          # uses the Operator's existing registered passkeys -- there is no
          # separate emergency passkey registration -- and it is identifier
          # first, because no earlier stage has selected the Operator.
          #
          # An already authenticated Operator is turned away rather than
          # switched: there is no supported transition between Normal and
          # Emergency inside a session, so the only route from one to the other
          # is the canonical sign-out ceremony.
          class PasskeysController < ::Auth::Org::ApplicationController
            include MinimumResponseBudget
            include ::CloudflareTurnstile
            include ::TurnstilePageProps
            include ::SurfaceInertiaPage
            include ::AuthenticationModeSwitchGuard

            AUTHENTICATION_MODE = :guest

            # GET /sign/in/emergency/passkey/new
            def new
              render inertia: true, props: emergency_passkey_sign_in_props
            end

            private

            def emergency_passkey_sign_in_props
              pt = signed_pt_param
              region = current_region_identifier
              scope = "sign.org.authentication.emergency.passkey.new"

              {
                title: page_t("#{scope}.page_title"),
                description: page_t("#{scope}.description"),
                restricted_mode_notice: page_t("#{scope}.restricted_mode_notice"),
                panel: {
                  options_url: auth_org_sign_in_emergency_passkey_options_path(pt: pt, ri: region),
                  verification_url: auth_org_sign_in_emergency_passkey_verification_path(pt: pt, ri: region),
                  region: region.to_s,
                  identifier_param: "identifier",
                  turnstile_site_key: turnstile_site_key(:CLOUDFLARE_TURNSTILE_SITE_STEALTH_KEY),
                  turnstile_error_message: t("turnstile_error"),
                  field: {
                    label: page_t("#{scope}.identifier_label"),
                    placeholder: page_t("#{scope}.identifier_placeholder"),
                    min_length: Operator::PUBLIC_ID_LENGTH,
                    max_length: Operator::PUBLIC_ID_LENGTH,
                    pattern: "[0-9A-FGHJKMNPQRSTVWXYZ]{16}",
                  },
                  submit_label: page_t("#{scope}.submit"),
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
end
