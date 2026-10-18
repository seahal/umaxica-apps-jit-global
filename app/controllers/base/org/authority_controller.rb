# typed: false
# frozen_string_literal: true

module Base
  module Org
    # Base protocol endpoints and Auth-result receivers use the root-session authority. They are
    # deliberately separate from the self-RP application controller and never accept RP cookies as
    # authentication proof.
    class AuthorityController < ::ApplicationController
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::DefaultNoStore
      include ::JumpRtReturnVerification
      include ::Session
      include ::PreferenceGlobal
      include ::PreferenceAdoption
      include ::BaseAdmissionBrowserBinding
      include ::AuthenticationOperator
      include ::SignErrorResponses
      include ::SessionLimitGate
      include ::AuthorizationAudit
      include ::AuthorizationOperator
      include ::VerificationOperator
      include ActionPolicy::Controller
      include ::ActorSupport
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all
      class << self
        public

        def base_admission_surface_name = "org"
      end

      layout "base/org/application"

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from AuthenticationBase::LoginCooldownError, with: :render_login_cooldown
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id,
                    :signed_pt_param, :current_operator, :logged_in?, :active_operator?, :logged_in_operator?

      allow_browser versions: :modern

      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "base_org_authority_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )
      before_action :set_current_context
      before_action :reset_flash
      before_action :set_preferences_cookie
      before_action :resolve_param_context
      before_action :set_region
      before_action :transparent_refresh_access_token, unless: -> { request.format.json? }
      before_action :set_current_actor
      before_action :apply_localization_preferences
      before_action :set_locale
      before_action :set_timezone
      before_action :set_color_theme
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      # Rails validates Origin and Fetch Metadata first; require its session-bound token before surface callbacks.
      prepend_before_action :require_authenticity_token_for_unsafe_request!
      protect_from_forgery using: :header_or_legacy_token, with: :exception, prepend: true
      ensure_fqdn_gate_first!
      prepend_before_action :apply_default_no_store

      private

      def require_authenticity_token_for_unsafe_request!
        return unless protect_against_forgery?
        return if request.get? || request.head? || verified_query_request?
        return if any_authenticity_token_valid?

        instrument_unverified_request
        handle_unverified_request
      end

      def sign_in_url_with_pt(_return_to)
        base_org_sign_show_path(ri: RequestContextContract.normalize_region(params[:ri]))
      end

      def oidc_sign_host
        ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      end

      def actor_verification_path(**args)
        base_org_verification_path(**args)
      end

      def actor_verification_setup_path(**args)
        base_org_verification_setup_path(**args)
      end

      def cross_host_redirect_allowed?
        true
      end
    end
  end
end
