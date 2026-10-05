# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Verification
      class SetupsController < ::Auth::Com::ApplicationController
        include ::SurfaceInertiaPage
        include ::AuthCeremonyAdmission
        include ::AuthStepUpCeremonyContext

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        def new
          admit_or_render_sign_ceremony!(expected_intent: "bootstrap") do
            return unless load_registration_ceremony_context!

            @missing_methods = admitted_step_up_methods
            render inertia: true, props: verification_setup_props
          end
        end

        private

        def auth_ceremony_entry_intent = "bootstrap"

        def auth_step_up_ceremony_clean_url = new_auth_com_verification_setup_path(ri: params[:ri])

        def auth_ceremony_admission_action_url = auth_com_verification_setup_path(ri: params[:ri])

        def ceremony_actor_model = Visitor

        def ceremony_step_up_session_model = VisitorStepUpSession

        def ceremony_session_token(record) = record.visitor_token

        def ceremony_token_owned_by?(token, actor) = token.visitor_id == actor.id

        def ceremony_supported_methods = [:passkey]

        def authorize_step_up_ceremony_actor!(actor)
          authorize!(actor, to: :show?, context: { user: actor })
        end

        def verification_setup_props
          {
            title: t("sign.app.verification.setup.title"),
            description: t("sign.app.verification.setup.description"),
            # Setup is shown only when no Step-Up method exists, so no earlier Step-Up state exists to go
            # back to, and the success continuation (`pt`) is not a Back. The only exit is cancellation.
            cancel: { label: t("actions.cancel"),
                      action: auth_com_verification_cancellation_path(ri: params[:ri]),
                      method: "post", },
            methods: verification_setup_methods,
          }
        end

        def verification_setup_methods
          methods = []

          if @missing_methods.include?(:passkey)
            methods << {
              key: "passkey",
              label: t("sign.app.verification.setup.methods.passkey"),
              href: new_auth_com_settings_passkey_path(ri: params[:ri]),
            }
          end

          methods
        end
      end
    end
  end
end
