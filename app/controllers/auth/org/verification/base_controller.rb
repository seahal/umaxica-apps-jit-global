# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Verification
      class BaseController < ::Auth::Org::ApplicationController
        include SignOrgVerificationBase
        include ::PreferenceGlobal
        include CommonOtp
        include ::AuthenticationOperator
        include ::VerificationOperator
        include SignVerificationTiming
        include SignVerificationCommonBase
        include SignVerificationAuditAndCookie
        include SignVerificationStepUpSessionStore
        include SignVerificationStepUpLifecycle
        include SignVerificationPasskeyChecks

        AUTHENTICATION_MODE = :private

        before_action :apply_localization_preferences
        before_action :authenticate_operator!
        before_action :set_actor_token
        before_action :require_ri!
        before_action :enforce_step_up_prereqs!
        skip_before_action :enforce_verification_if_required
        before_action :authorize_verification_actor!

        private

        def authorize_verification_actor!
          authorize!(current_verification_actor, to: :show?)
        end

        # Cancel ends the whole Step-Up ceremony, unlike Back, which only returns to method selection.
        # The cancellation endpoint picks the destination from the server-held ceremony origin.
        def step_up_cancellation_props
          { label: t("actions.cancel"),
            action: auth_org_verification_cancellation_path(ri: params[:ri]),
            method: "post", }
        end

        def valid_step_up_session?(rs)
          rs.present? &&
            rs.discard_at > Time.current &&
            rs.staff_token_id == actor_token.id &&
            rs.status == "PENDING" &&
            rs.scope.present? &&
            rs.return_to.present?
        end

        def handle_invalid_step_up_session!
          clear_step_up_state!
          safe_redirect_to(
            auth_org_settings_path(ri: params[:ri]),
            fallback: "/settings",
          )
          false
        end

        def clear_step_up_state!
          true
        end

        def verification_model = OperatorVerification

        def verification_success_event_id = OperatorChronicleEvent::STEP_UP_VERIFIED

        def verification_success_notice_key = "sign.org.verification.success.complete"

        def verification_success_fallback_path = auth_org_verification_path(ri: params[:ri])

        def verification_audit_event_class = OperatorChronicleEvent

        def verification_audit_level_class = OperatorChronicleLevel

        def verification_default_activity_level_id = OperatorChronicleLevel::NOTHING

        def verification_activity_model = OperatorChronicle

        def current_verification_actor = current_operator

        def verification_actor_type = "Operator"

        def verification_passkeys_scope = current_operator.staff_passkeys

        def verification_passkey_model = OperatorPasskey

        def passkey_actor_matches?(passkey) = passkey.staff_id == current_operator.id

        def verification_no_passkey_i18n_key = "sign.org.verification.errors.no_passkey"
      end
    end
  end
end
