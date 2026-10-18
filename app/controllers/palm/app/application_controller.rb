# typed: false
# frozen_string_literal: true

module Palm
  module App
    # Base for Palm's browser RP pages. Machine endpoints (health, robots, sitemap, JWKS and CSP
    # reports) stay on BareController and deliberately do not participate in browser authentication.
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
      include ::AuthorizationClient
      include ::VerificationClient
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
      layout "palm/app/application"

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception
      prepend_before_action :require_authenticity_token_for_unsafe_request!
      ensure_fqdn_gate_first!

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from AuthenticationBase::LoginCooldownError, with: :render_login_cooldown
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id,
                    :signed_pt_param, :current_client, :logged_in?, :active_client?, :logged_in_client?

      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays an effect-free helper; the limit and its numeric
      # value are declared here on the inheriting controller.
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "palm_app_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )

      # Palm renders regional HTML, so it owes the same `ri` contract as every other HTML surface:
      # a GET/HEAD without a valid region is redirected to the canonical URL that carries one, and
      # `PreferenceGlobal#default_url_options` then propagates it into every generated link.
      # See docs/architecture/preference.md and test/unit/security/ri_routing_contract_test.rb.
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
      before_action :enforce_withdrawal_gate!
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      public

      def oidc_client_id
        RpDeploymentBindingValue.client_id("palm-app")
      end

      def browser_rp_client_id
        RpDeploymentBindingValue.client_id("palm-app")
      end

      def browser_rp_resource_type
        "client"
      end

      public :browser_rp_client_id, :browser_rp_resource_type

      def oidc_sign_host
        ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      end

      def oidc_base_authority_host
        ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      end

      def oidc_acme_host
        oidc_base_authority_host
      end

      private

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
