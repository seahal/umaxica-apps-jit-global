# typed: false
# frozen_string_literal: true

module Core
  module Org
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
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
      include ::ActorSupport
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all
      after_action :verify_private_action_authorized!
      after_action :apply_authenticated_page_cache_policy!
      helper_method :current_resource, :browser_rp_authenticated?, :browser_rp_session_public_id,
                    :current_browser_session_security_context, :current_session_public_id,
                    :current_session, :logged_in?
      before_action :authenticate_browser_rp_safe_request!
      prepend_before_action :authenticate_browser_rp_unsafe_request!
      ensure_fqdn_gate_first!

      layout "core/org/application"

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from AuthenticationBase::LoginCooldownError, with: :render_login_cooldown
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id,
                    :signed_pt_param, :current_operator, :logged_in?, :active_operator?, :logged_in_operator?

      # Existing jump-return handling runs before rate limiting; keep that order
      # for this extraction and review the risk in a follow-up lifecycle PR.
      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays an effect-free helper; the limit and its numeric
      # value are declared here on the inheriting controller.
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "core_org_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )
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
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      def oidc_client_id
        RpDeploymentBindingValue.client_id("core-org")
      end

      def browser_rp_client_id
        RpDeploymentBindingValue.client_id("core-org")
      end

      def browser_rp_resource_type
        "operator"
      end

      public :browser_rp_client_id, :browser_rp_resource_type

      def oidc_sign_host
        ENV.fetch("PRIVATE_AUTH_STAFF_URL")
      end

      def oidc_visa_authority_host
        Rails.configuration.x.boot_config.fetch(:hosts).visa_staff.host
      end

      def oidc_acme_host
        oidc_visa_authority_host
      end

      private

      def preference_dbsc_path
        dbsc_canonical_url(core_org_api_v0_preferences_dbsc_path)
      end
    end
  end
end
