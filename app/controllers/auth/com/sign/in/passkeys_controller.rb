# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module In
        class PasskeysController < ::Auth::Com::ApplicationController
          include ::AuthenticationModeSwitchGuard
          include MinimumResponseBudget

          include SessionLimitGate

          include CloudflareTurnstile
          include ::SurfaceInertiaPage
          include ::TurnstilePageProps

          AUTHENTICATION_MODE = :guest
          before_action :start_minimum_response_budget
          after_action :enforce_minimum_response_budget

          def new
            render inertia: true, props: sign_in_passkey_new_props
          end

          private

          def sign_in_passkey_new_props
            pt = signed_pt_param
            ri = current_region_identifier

            {
              title: t("sign.app.authentication.passkey.new.page_title"),
              description: t("sign.app.authentication.passkey.new.description"),
              panel: {
                options_url: auth_com_sign_in_passkey_options_path(pt: pt, ri: ri),
                verification_url: auth_com_sign_in_passkey_verification_path(pt: pt, ri: ri),
                region: ri.to_s,
                identifier_param: nil,
                turnstile_site_key: turnstile_stealth_props.fetch(:site_key),
                turnstile_error_message: t("turnstile_error"),
                field: nil,
                submit_label: t("sign.app.authentication.passkey.new.submit"),
              },
              back_link: {
                label: t("sign.app.authentication.new.back"),
                href: auth_com_sign_in_path(pt: pt, ri: ri),
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
