# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module In
        # PasskeysController handles Passkey-based user authentication.
        #
        # Flow:
        # 1. User visits /in/passkeys/new and enters their email
        # 2. POST /in/passkeys/options with email to get WebAuthn challenge
        # 3. Browser performs navigator.credentials.get()
        # 4. POST /in/passkeys/verification with credential + challenge_id
        # 5. Server verifies and establishes session via AuthenticationBase#log_in
        #
        # Note: Discoverable credentials (passwordless without identifier) are
        # planned for a future phase. Currently, email is required to look up
        # the user's registered passkeys.
        class PasskeysController < ::Auth::App::ApplicationController
          include ::AuthenticationModeSwitchGuard
          include ::SurfaceInertiaPage

          include EmailValidation

          include IdentifierDetection

          include MinimumResponseBudget

          include SessionLimitGate

          include CloudflareTurnstile

          AUTHENTICATION_MODE = :guest
          before_action :start_minimum_response_budget
          after_action :enforce_minimum_response_budget

          # GET /in/passkeys/new
          # Render login page with email input and passkey button
          def new
            render inertia: true, props: passkey_new_props
          end

          private

          def passkey_new_props
            scope = "sign.app.authentication.passkey.new"
            pt = signed_pt_param
            ri = current_region_identifier

            {
              title: page_t("#{scope}.page_title"),
              description: page_t("#{scope}.description"),
              panel: {
                options_url: auth_app_sign_in_passkey_options_path(pt: pt, ri: ri),
                verification_url: auth_app_sign_in_passkey_verification_path(pt: pt, ri: ri),
                region: ri.to_s,
                identifier_param: "identifier",
                # The stealth site key is public by design and the ERB already published it in the
                # rendered HTML; the secret key and the token verification stay server side.
                turnstile_site_key: JitSecurityTurnstileConfig.stealth_site_key.to_s,
                turnstile_error_message: t("turnstile_error"),
                field: {
                  label: page_t("#{scope}.pii_label"),
                  placeholder: page_t("#{scope}.pii_placeholder"),
                },
                submit_label: page_t("#{scope}.submit"),
              },
              back_link: {
                label: t("sign.app.authentication.new.back"),
                href: auth_app_sign_in_path(pt: pt, ri: ri),
              },
            }
          end

          def minimum_response_budget_enabled?
            action_name == "options"
          end
        end
      end
    end
  end
end
