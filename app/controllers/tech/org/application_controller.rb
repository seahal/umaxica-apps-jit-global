# typed: false
# frozen_string_literal: true

module Tech
  module Org
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::DefaultNoStore
      include ::JumpRtReturnVerification
      include ::Session
      include ::PreferenceGlobal
      include ::PreferenceAdoption
      include ::BrowserRpAuthentication
      include ::AuthenticationWithdrawalGate
      include ::BrowserRpSafeRequestRefresh
      include ::BrowserRpUnsafeRequestRefresh
      include ::SignErrorResponses
      include ::SessionLimitGate
      include ::AuthorizationAudit
      include ::AuthorizationOperator
      include ::VerificationOperator
      include ActionPolicy::Controller
      include ::OidcSsoInitiator
      include SurfaceRouteAliasHelper
      include ::ActorSupport
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      after_action :verify_private_action_authorized!
      after_action :apply_authenticated_page_cache_policy!
      helper_method :current_resource, :browser_rp_authenticated?, :browser_rp_session_public_id,
                    :current_browser_session_security_context, :current_session_public_id,
                    :current_session, :logged_in?, :current_actor, :current_account,
                    :current_operator, :active_operator?, :logged_in_operator?,
                    :signed_pt_param
      before_action :authenticate_browser_rp_safe_request!
      prepend_before_action :authenticate_browser_rp_unsafe_request!

      layout "tech/org/application"

      allow_browser versions: :modern
      protect_from_forgery using: :header_or_legacy_token, with: :exception
      prepend_before_action :require_authenticity_token_for_unsafe_request!
      ensure_fqdn_gate_first!
      prepend_before_action :apply_default_no_store

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from AuthenticationBase::LoginCooldownError, with: :render_login_cooldown
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error

      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "tech_org_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )

      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
      before_action :set_current_context
      before_action :reset_flash
      before_action :set_preferences_cookie
      before_action :resolve_param_context
      before_action :set_region
      before_action :set_current_actor
      before_action :apply_localization_preferences
      before_action :set_locale
      before_action :set_timezone
      before_action :set_color_theme
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :enforce_tech_access!, if: :tech_private_action?
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      public

      def oidc_client_id = "tech-org-ww"

      def browser_rp_client_id = "tech-org-ww"

      def browser_rp_resource_type = "operator"

      def oidc_sign_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")

      def oidc_base_authority_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")

      def oidc_acme_host = oidc_base_authority_host

      public :browser_rp_client_id, :browser_rp_resource_type

      private

      def tech_private_action?
        self.class.authentication_mode_for(action_name) == :private
      end

      # R5-WU11: the org authority decides tech.access over HTTPS for every private Tech action,
      # from the Operator's current Access JWT; any failure denies (no positive cache).
      def enforce_tech_access!
        access_token = BrowserCredentialCookie.read(cookies, OidcRpBrowserCredentialContract::ACCESS_COOKIE)
        authorize!(TechRemoteAccessPolicy::Request.new(access_token:), to: :show?, with: TechRemoteAccessPolicy)
      end

      def handle_authorization_error(exception)
        log_authorization_failure(exception)
        response.set_header("Cache-Control", "no-store")
        render "tech/org/access_denials/show", status: :forbidden
      end

      def require_authenticity_token_for_unsafe_request!
        return unless protect_against_forgery?
        return if request.get? || request.head? || verified_query_request?
        return if any_authenticity_token_valid?

        instrument_unverified_request
        handle_unverified_request
      end
    end
  end
end
