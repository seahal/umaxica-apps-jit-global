# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Verification
      # The step-up seams for this surface live in SignComVerificationBase::Overrides, which is
      # prepended below and therefore wins over anything defined in this class body. Add surface
      # behaviour there, not here, or it will never run.
      class BaseController < ::Auth::Com::ApplicationController
        include SignComVerificationBase
        include ::PreferenceGlobal
        include CommonOtp
        include ::AuthenticationVisitor
        include ::VerificationVisitor
        include SignVerificationTiming
        include SignVerificationCommonBase
        include SignVerificationAuditAndCookie
        include SignVerificationStepUpSessionStore
        include SignVerificationStepUpLifecycle
        include SignVerificationPasskeyChecks
        include SignEmailOtpVerificationSupport
        prepend SignComVerificationBase::Overrides

        AUTHENTICATION_MODE = :private

        before_action :apply_localization_preferences
        before_action :authenticate_visitor!
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

        # Cancel ends the whole Step-Up ceremony, unlike Back, which only returns to method selection.
        # The cancellation endpoint picks the destination from the server-held ceremony origin.
        def step_up_cancellation_props
          { label: t("actions.cancel"),
            action: auth_com_verification_cancellation_path(ri: params[:ri]),
            method: "post", }
        end

        # The step-up completion hand-off is an auto-submitting ERB document, not an Inertia page.
        # Descendants that render Inertia carry the Inertia layout, which has no `yield`, so the
        # completion template names the document layout explicitly and reaches acme unchanged.
        # Overrides does not define this, so the class body is still the live definition.
        def step_up_handoff_layout
          "auth/com/application"
        end
      end
    end
  end
end
