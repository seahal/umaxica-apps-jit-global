# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Verification
      class SetupsController < ::Auth::App::ApplicationController
        include ::SurfaceInertiaPage
        include ::AuthCeremonyAdmission
        include ::AuthStepUpCeremonyContext

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        def new
          admit_or_render_sign_ceremony!(expected_intent: "bootstrap") do
            return unless load_registration_ceremony_context!

            @missing_methods = admitted_step_up_methods
            render inertia: true, props: setup_page_props
          end
        end

        private

        def auth_ceremony_entry_intent = "bootstrap"

        # Base admits one registration method per bootstrap, so the browser goes straight to that
        # method's ceremony. A bootstrap that still carries several methods shows the choice here.
        def auth_step_up_ceremony_clean_url
          if auth_ceremony_registration_transaction&.allowed_methods_array == ["totp"]
            new_auth_app_settings_totp_path(ri: params[:ri])
          else
            new_auth_app_verification_setup_path(ri: params[:ri])
          end
        end

        def auth_ceremony_admission_action_url = auth_app_verification_setup_path(ri: params[:ri])

        def ceremony_actor_model = Client

        def ceremony_step_up_session_model = ClientStepUpSession

        def ceremony_session_token(record) = record.user_token

        def ceremony_token_owned_by?(token, actor) = token.user_id == actor.id

        def ceremony_supported_methods = %i(passkey totp)

        def authorize_step_up_ceremony_actor!(actor)
          authorize!(actor, to: :show?, context: { user: actor })
        end

        # Only the methods the actor has yet to register are offered; a method they already hold is
        # absent rather than rendered and hidden.
        def setup_page_props
          {
            title: t("sign.app.verification.setup.title"),
            heading: t("sign.app.verification.setup.title"),
            description: t("sign.app.verification.setup.description"),
            # Setup is shown only when no Step-Up method exists, so no earlier Step-Up state exists to go back
            # to, and the success continuation (`pt`) is not a Back. Cancellation is the only exit that
            # closes the ceremony.
            cancel: { label: t("actions.cancel"),
                      action: auth_app_verification_cancellation_path(ri: params[:ri]),
                      method: "post", },
            methods: setup_methods,
          }
        end

        def setup_methods
          links = []

          if @missing_methods.include?(:passkey)
            links << {
              key: "passkey",
              label: t("sign.app.verification.setup.methods.passkey"),
              href: new_auth_app_settings_passkey_path(ri: params[:ri]),
            }
          end

          if @missing_methods.include?(:totp)
            links << {
              key: "totp",
              label: t("sign.app.verification.setup.methods.totp"),
              href: new_auth_app_settings_totp_path(ri: params[:ri]),
            }
          end

          links << email_registration_link
        end

        # Email is not an admitted method of this ceremony: Base owns email registration under its own
        # browser session and bootstrap exemption. Bootstrap is issued only to an actor without a
        # confirmed email, so the entry is always offered. Following it leaves the pending transaction
        # untouched; confirming the address on Base revokes it through CredentialSecurityTransition.
        def email_registration_link
          {
            key: "email",
            label: t("sign.app.verification.setup.methods.email"),
            href: new_base_app_identity_emails_registration_url(
              ri: params[:ri], host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), protocol: "https",
            ),
          }
        end
      end
    end
  end
end
