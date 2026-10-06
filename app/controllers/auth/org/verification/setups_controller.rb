# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Verification
      class SetupsController < ::Auth::Org::ApplicationController
        include ::SurfaceInertiaPage
        include ::AuthCeremonyAdmission
        include ::AuthStepUpCeremonyContext

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        def new
          admit_or_render_sign_ceremony!(expected_intent: "bootstrap") do
            return unless load_registration_ceremony_context!

            @missing_methods = admitted_step_up_methods
            render inertia: true, props: setup_props
          end
        end

        private

        def auth_ceremony_entry_intent = "bootstrap"

        def auth_step_up_ceremony_clean_url
          if auth_ceremony_registration_transaction&.allowed_methods_array == ["passkey"]
            new_auth_org_verification_registration_passkey_path(ri: params[:ri])
          else
            new_auth_org_verification_setup_path(ri: params[:ri])
          end
        end

        def auth_ceremony_admission_action_url = auth_org_ceremony_bindings_path

        def auth_ceremony_admitted_action_url = auth_org_verification_setup_path(ri: params[:ri])

        def ceremony_actor_model = Operator

        def ceremony_step_up_session_model = OperatorStepUpSession

        def ceremony_session_token(record) = record.staff_token

        def ceremony_token_owned_by?(token, actor) = token.staff_id == actor.id

        def ceremony_supported_methods = [:passkey]

        def authorize_step_up_ceremony_actor!(actor)
          authorize!(actor, to: :show?, context: { user: actor })
        end

        # Only the methods the operator still has to configure are offered; a method already in
        # place is absent rather than rendered and disabled.
        def setup_props
          {
            title: t("sign.org.verification.setup.title"),
            description: t("sign.org.verification.setup.description"),
            # Setup is shown only when no Step-Up method exists, so no earlier Step-Up state exists to go
            # back to, and the success continuation (`pt`) is not a Back. The only exit is cancellation.
            cancel: { label: t("actions.cancel"),
                      action: auth_org_verification_cancellation_path(ri: params[:ri]),
                      method: "post", },
            methods: if @missing_methods.include?(:passkey)
                       [{
                         key: "passkey",
                         label: t("sign.org.verification.setup.methods.passkey"),
                         href: new_auth_org_verification_registration_passkey_path(ri: params[:ri]),
                       }]
                     else
                       []
                     end,
          }
        end
      end
    end
  end
end
