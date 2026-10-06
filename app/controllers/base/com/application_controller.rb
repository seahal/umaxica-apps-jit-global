# typed: false
# frozen_string_literal: true

module Base
  module Com
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::DefaultNoStore
      include ::JumpRtReturnVerification

      include ::Session

      include ::PreferenceGlobal

      include ::PreferenceAdoption

      include ::BrowserRpAuthentication
      include ::BrowserRpSafeRequestRefresh
      include ::BrowserRpUnsafeRequestRefresh
      include ::BaseAdmissionBrowserBinding
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
      base_admission_surface "com"

      prepend_before_action :apply_default_no_store

      layout "base/com/application"

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from AuthenticationBase::LoginCooldownError, with: :render_login_cooldown
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id, :current_session_restricted?,
                    :signed_pt_param, :current_visitor, :logged_in?, :active_visitor?, :logged_in_visitor?

      allow_browser versions: :modern

      # NOTE: Order matters (dependencies rely on this sequence)
      # Layer order: explicit RateLimit -> CurrentContext -> Preference -> AuthN ->
      # CurrentActor -> effect reflection -> Verification -> AuthZ
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
        scope: "base_com_default_web",
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
      before_action :enforce_withdrawal_gate!
      before_action :enforce_restricted_session_guard!
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      protect_from_forgery using: :header_or_legacy_token, with: :exception

      private

      def browser_rp_client_id
        "base-com-ww"
      end

      def browser_rp_resource_type
        "visitor"
      end

      def oidc_client_id
        browser_rp_client_id
      end

      def sign_in_url_with_pt(pt)
        base_com_sign_show_path(
          ri: RequestContextContract.normalize_region(params[:ri]),
          pt: decode_pt(pt).presence,
        )
      end

      # The browser is redirected to this host for the OIDC hop, so it has to be the public
      # Auth origin, matching Base::App::ApplicationController. An internal host here sends
      # the visitor to a name their browser cannot resolve.
      def oidc_sign_host
        ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
      end

      def oidc_base_authority_host
        ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
      end

      private

      def actor_verification_path(**args)
        base_com_verification_path(**args)
      end

      # Base collects consent and issues the scoped admission before leaving its root session.
      def actor_verification_setup_path(**args)
        base_com_verification_setup_path(**args)
      end

      def cross_host_redirect_allowed?
        true
      end
    end
  end
end
