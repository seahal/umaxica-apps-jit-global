# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module In
        class PasskeysController < ::Auth::Com::ApplicationController
          include ::AuthenticationModeSwitchGuard
          include EmailValidation

          include IdentifierDetection

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

          # IdentifierDetection is included here, so its client-surface defaults sit ahead
          # of Auth::Com::ApplicationController in the lookup and would resolve a corporate
          # identifier against ClientEmail/ClientTelephone. Only #new is routed here today,
          # so nothing reaches the lookup, but the seam must name the corporate records for
          # the same reason the sibling Passkey::OptionsController does.
          def identity_email_model = VisitorEmail

          def identity_telephone_model = VisitorTelephone

          def identity_from_email_record(record) = record&.visitor

          def identity_from_telephone_record(record) = record&.visitor

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
                identifier_param: "identifier",
                turnstile_site_key: turnstile_stealth_props.fetch(:site_key),
                turnstile_error_message: t("turnstile_error"),
                field: {
                  label: t("sign.app.authentication.passkey.new.pii_label"),
                  placeholder: t("sign.app.authentication.passkey.new.pii_placeholder"),
                  min_length: 0,
                  max_length: 255,
                  pattern: ".*",
                },
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
