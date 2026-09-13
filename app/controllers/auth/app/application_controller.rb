# typed: false
# frozen_string_literal: true

module Auth
  module App
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::WebauthnSurfaceDeclarable

      webauthn_surface :app
      include ::JumpRtReturnVerification
      include ::Session
      include ::PreferenceGlobal
      # Adopt anonymous preference cookies into the signed-in user account after authentication.
      include ::PreferenceAdoption
      include ::SignSignupObservability
      include ::AuthenticationClient
      include ::SignErrorResponses
      include ::SessionLimitGate
      include ::AuthorizationAudit
      include ::AuthenticationCredentialInventoryReader
      include ::AuthorizationClient
      include ::VerificationClient
      include ActionPolicy::Controller
      include ::OidcSsoInitiator
      # Note: RestrictedSessionGuard is still needed to enforce session expiration
      # and block expired restricted sessions on the session management page itself.
      include ::RestrictedSessionGuard
      include SurfaceRouteAliasHelper
      include ::ActorSupport
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      layout "auth/app/application"

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: JitHostOriginEnv.trusted_origins(
                             ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                           ),
                           with: :exception

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from AuthenticationBase::LoginCooldownError, with: :render_login_cooldown
      rescue_from AlreadyAuthenticatedError, with: :render_sign_in_unavailable_while_authenticated
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id, :current_session_restricted?,
                    :signed_pt_param, :current_client, :logged_in?, :active_client?, :logged_in_client?,
                    :current_region_identifier
      helper_method :acme_authority_host, :base_authority_host

      # NOTE: Order matters (dependencies rely on this sequence)
      # Jump-return handling runs before rate limiting so that cross-surface
      # navigations arriving via jump.umaxica.net can strip the rt parameter
      # and redirect before consuming a rate-limit slot.
      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays a side-effect-free helper; the limit and its numeric
      # value are declared here on the inheriting controller.
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "auth_app_default_web",
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
      before_action :enforce_withdrawal_gate!
      # Restricted session guard - explicitly enabled to handle expired sessions
      # and prevent access to non-allowed routes for restricted sessions
      before_action :enforce_restricted_session_guard!
      before_action :enforce_sign_in_selector_gate!
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      private

      # Direct Auth entrypoints send signed-in clients to Base, which owns dashboard authority.
      def after_login_path
        return oidc_authorization_after_login_path if oidc_authorization_login_challenge.present?

        base_app_dashboard_url(ri: current_region_identifier, host: base_authority_host)
      end

      def after_login_allows_other_host?
        true
      end

      def cross_host_redirect_allowed?
        true
      end

      def oidc_client_id
        "sign-rp"
      end

      def oidc_sign_host
        ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      end

      def oidc_acme_host
        ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      end

      def oidc_base_authority_host
        oidc_acme_host
      end

      def oidc_authorization_login_challenge
        session[:oidc_authorization_login_challenge]
      end

      def oidc_authorization_after_login_path
        challenge = oidc_authorization_login_challenge
        register_oidc_authorization_result!(challenge).resume_url
      ensure
        session.delete(:oidc_authorization_login_challenge)
      end

      def register_oidc_authorization_result!(login_challenge)
        OidcAuthorizationTransactionCoordinator.register_result!(
          surface: "app",
          login_challenge: login_challenge,
          actor: current_resource,
          session_ref: current_session_public_id,
          auth_method: Array(Actor.authn.access_claims&.dig("amr")).first || "unknown",
          acr: Actor.authn.access_claims&.dig("acr"),
        )
      end

      def acme_authority_host
        oidc_acme_host
      end

      def base_authority_host
        ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      end
    end
  end
end
