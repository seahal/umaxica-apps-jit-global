# typed: false
# frozen_string_literal: true

module Side
  module Com
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::JumpRtReturnVerification
      include ::Session
      include ::PreferenceGlobal
      include ::AuthenticationVisitor
      include ::SignErrorResponses
      include ::SessionLimitGate
      include ::AuthorizationAudit
      include ::AuthorizationVisitor
      include ::VerificationVisitor
      include ActionPolicy::Controller
      include ::OidcSsoInitiator
      include ::RestrictedSessionGuard
      include ::ActorSupport
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      layout "side/com/application"

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: JitHostOriginEnv.trusted_origins(
                             ENV.fetch("PUBLIC_SIDE_CORPORATE_URL"),
                           ),
                           with: :exception

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from AuthenticationBase::LoginCooldownError, with: :render_login_cooldown
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id, :current_session_restricted?,
                    :signed_pt_param, :current_visitor, :logged_in?, :active_visitor?, :logged_in_visitor?

      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "side_com_default_web",
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
      before_action :enforce_restricted_session_guard!
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      def oidc_client_id
        "side-com"
      end

      def oidc_sign_host
        ENV.fetch("PRIVATE_AUTH_CORPORATE_URL")
      end

      def oidc_base_authority_host
        ENV.fetch("PRIVATE_BASE_CORPORATE_URL")
      end

      def oidc_acme_host
        oidc_base_authority_host
      end
    end
  end
end
