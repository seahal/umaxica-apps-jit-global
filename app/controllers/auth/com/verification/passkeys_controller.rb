# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Verification
      class PasskeysController < ::Auth::Com::Verification::BaseController
        include SignVerificationPasskeyActions
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private

        NEW_COMPONENT = "auth/com/verification/passkeys/new"

        private

        # The assertion is still posted back as a document submission, so the failure path keeps its
        # 422; only the rendering of the challenge page moved to React.
        def render_verification_passkey_page(status: :ok)
          render inertia: NEW_COMPONENT, props: new_page_props, status: status
        end

        def new_page_props
          scope = incoming_scope.presence || params[:scope].presence
          pt = incoming_pt.presence || params[:pt].presence

          {
            title: t("sign.app.verification.edit.title"),
            heading: t("sign.app.verification.edit.title"),
            description: t("sign.app.verification.edit.description"),
            errors: Array(@verification_errors),
            form: {
              action: auth_com_verification_passkey_path(ri: params[:ri]),
              csrf_token: form_authenticity_token,
              scope: scope,
              pt: pt,
              challenge_id: @passkey_challenge_id.to_s,
              # The challenge the server just issued for this actor. The ERB embedded the same
              # payload; it is what `navigator.credentials.get` consumes and carries no secret.
              request_options: passkey_request_options_payload,
              submit_label: t("sign.app.verification.edit.authenticate_with_passkey"),
            },
            cancel: step_up_cancellation_props,
            back: {
              label: t("sign.app.verification.edit.back"),
              href: auth_com_verification_path(ri: params[:ri], scope: scope, pt: pt),
            },
          }
        end

        def passkey_request_options_payload
          return nil if @passkey_request_options.blank?

          JSON.parse(@passkey_request_options.to_json)
        end
      end
    end
  end
end
