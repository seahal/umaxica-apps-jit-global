# typed: false
# frozen_string_literal: true

module Base
  module App
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

      include ::AuthorizationClient

      include ::VerificationClient

      include ActionPolicy::Controller
      include ::OidcSsoInitiator
      include ::RestrictedSessionGuard

      include SurfaceRouteAliasHelper
      include ::ActorSupport

      include ::Finisher

      AUTHENTICATION_MODE = :deny_all
      base_admission_surface "app"

      prepend_before_action :apply_default_no_store

      layout "base/app/application"

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from AuthenticationBase::LoginCooldownError, with: :render_login_cooldown
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id, :current_session_restricted?,
                    :signed_pt_param, :current_client, :logged_in?, :active_client?, :logged_in_client?,
                    :apple_only_credential?

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
        scope: "base_app_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )
      before_action :set_current_context
      before_action :reset_flash
      # Preference transport and request-local context must run before Actor hydration.
      before_action :set_preferences_cookie
      before_action :resolve_param_context
      before_action :set_region

      before_action :set_current_actor
      before_action :apply_localization_preferences
      # These side effects reflect Actor.preferences for the current request only.
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

      def current_verification_actor
        current_client
      end

      def browser_rp_client_id
        "base-app-ww"
      end

      def browser_rp_resource_type
        "client"
      end

      def oidc_client_id
        browser_rp_client_id
      end

      def sign_in_url_with_pt(pt)
        base_app_sign_show_path(
          ri: RequestContextContract.normalize_region(params[:ri]),
          pt: decode_pt(pt).presence,
        )
      end

      def oidc_sign_host
        ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      end

      def oidc_base_authority_host
        ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      end

      private

      def apple_only_credential?
        AppleOnlyCredentialStatus.call(current_client)
      end

      # The Inertia props for the "add another sign-in method" prompt, or nil when the actor already
      # has another credential. Returning nil keeps the decision on the server: a page that is not
      # given the prop cannot show the prompt.
      def apple_only_credential_warning_props
        return unless apple_only_credential?

        {
          heading: t("base.app.identity.credential_warning.heading"),
          body: t("base.app.identity.credential_warning.body"),
          items: [
            {
              label: t("base.app.identity.credential_warning.passkey"),
              href: new_base_app_identity_passkey_url(
                ri: params[:ri], host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), protocol: "https",
              ),
            },
            {
              label: t("base.app.identity.credential_warning.google"),
              href: apple_only_credential_auth_url(:edit_auth_app_settings_google_url),
            },
          ],
        }
      end

      def apple_only_credential_auth_url(route_helper)
        public_send(
          route_helper,
          ri: params[:ri],
          host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
          protocol: "https",
        )
      end

      def actor_verification_path(**args)
        base_app_verification_path(**args)
      end

      # Base collects consent and issues the scoped admission before leaving its root session.
      def actor_verification_setup_path(**args)
        base_app_verification_setup_path(**args)
      end

      def cross_host_redirect_allowed?
        true
      end
    end
  end
end
