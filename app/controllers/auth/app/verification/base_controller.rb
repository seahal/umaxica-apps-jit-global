# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Verification
      class BaseController < ::Auth::App::ApplicationController
        include ::CloudflareTurnstile

        include SignAppVerificationBase
        include ::PreferenceGlobal
        include CommonOtp
        include ::VerificationClient
        include SignVerificationTiming
        include SignVerificationCommonBase
        include SignVerificationAuditAndCookie
        include SignVerificationStepUpSessionStore
        include SignVerificationStepUpLifecycle
        include SignVerificationPasskeyChecks
        include SignVerificationTotpChecks

        AUTHENTICATION_MODE = :private

        before_action :apply_localization_preferences
        before_action :authenticate_client!
        before_action :set_actor_token
        before_action :require_ri!
        before_action :enforce_step_up_prereqs!
        skip_before_action :enforce_verification_if_required
        before_action :authorize_verification_actor!
        helper_method :current_step_up_scope, :current_step_up_pt_param

        private

        def authorize_verification_actor!
          authorize!(current_verification_actor, to: :show?)
        end

        def valid_step_up_session?(rs)
          rs.present? &&
            rs.discard_at > Time.current &&
            rs.user_token_id == actor_token.id &&
            rs.status == "PENDING" &&
            rs.scope.present? &&
            rs.return_to.present?
        end

        def handle_invalid_step_up_session!
          clear_step_up_state!
          destroy_current_step_up_session!

          if restore_step_up_session_from_params! && valid_step_up_session?(current_step_up_session)
            return true
          end

          safe_redirect_to(
            auth_app_settings_path(ri: params[:ri]),
            fallback: auth_app_root_path(ri: params[:ri]),
          )
          false
        end

        def verification_unavailable_redirect_path
          auth_app_verification_path(ri: params[:ri])
        end

        # The step-up completion hand-off is an auto-submitting ERB document, not an Inertia page.
        # The descendants that render Inertia carry the Inertia layout, which has no `yield`, so the
        # completion template names the document layout explicitly and reaches acme unchanged.
        def render_acme_step_up_completion!(result_token:, ri:)
          render(
            "sign/shared/step_up_completion",
            layout: "auth/app/application",
            locals: {
              completion_url: acme_step_up_completion_url_for(step_up_ceremony_surface),
              result_token: result_token,
              ri: ri,
              csrf_token: acme_step_up_completion_csrf_token,
            },
          )
        end

        def clear_step_up_state!
          session.delete(email_otp_session_key) if step_up_session_storage_available?
        end

        def verification_model
          ClientVerification
        end

        def verification_success_event_id
          ClientChronicleEvent::STEP_UP_VERIFIED
        end

        def verification_success_notice_key
          "sign.app.verification.success.complete"
        end

        def verification_success_fallback_path
          auth_app_verification_path(ri: params[:ri])
        end

        def verification_audit_event_class = ClientChronicleEvent

        def verification_audit_level_class = ClientChronicleLevel

        def verification_default_activity_level_id = ClientChronicleLevel::NOTHING

        def verification_activity_model = ClientChronicle

        def current_verification_actor = current_client

        def verification_actor_type = "Client"

        def verification_passkeys_scope
          current_client.client_passkeys
        end

        def verification_passkey_model
          ClientPasskey
        end

        def passkey_actor_matches?(passkey)
          passkey.user_id == current_client.id
        end

        def verification_no_passkey_i18n_key
          "sign.app.verification.errors.no_passkey"
        end

        def active_totp_credentials
          current_client.client_totp_credentials
            .where(user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
            .order(created_at: :desc)
        end
      end
    end
  end
end
