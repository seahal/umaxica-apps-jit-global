# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::JumpRtReturnVerification
      include ::DefaultNoStore
      include ::WebauthnSurfaceDeclarable

      webauthn_surface :org
      include ::Session
      include ::PreferenceGlobal
      include ::PreferenceAdoption
      include ::SignSignupObservability
      include ::AuthenticationOperator
      include ::SignErrorResponses
      include ::SessionLimitGate
      include ::AuthorizationAudit
      include ::AuthenticationCredentialInventoryReader
      include ::AuthorizationOperator
      include ::VerificationOperator
      include ActionPolicy::Controller
      include ::AuthCeremonyContext
      include ::RestrictedSessionGuard
      include SurfaceRouteAliasHelper
      include ::ActorSupport
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      prepend_before_action :apply_default_no_store

      AUTH_CEREMONY_SURFACE = "org"

      layout "auth/org/application"

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from AuthenticationBase::LoginCooldownError, with: :render_login_cooldown
      rescue_from AlreadyAuthenticatedError, with: :render_sign_in_unavailable_while_authenticated
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id, :current_session_restricted?,
                    :signed_pt_param, :current_operator, :logged_in?, :active_operator?, :logged_in_operator?,
                    :current_region_identifier
      helper_method :acme_authority_host, :base_authority_host

      # Restricted session guard - explicitly enabled to block restricted sessions
      # from accessing routes other than /in/session
      # NOTE: Order matters (dependencies rely on this sequence)
      # Layer order: explicit RateLimit -> CurrentContext -> Preference -> AuthN ->
      # CurrentActor -> effect reflection -> Verification -> AuthZ
      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays an effect-free helper; the limit and its numeric
      # value are declared here on the inheriting controller.
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "auth_org_default_web",
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
      before_action :transparent_refresh_access_token, unless: -> { request.format.json? }
      before_action :set_current_actor
      before_action :apply_localization_preferences
      before_action :set_locale
      before_action :set_timezone
      before_action :set_color_theme
      before_action :enforce_withdrawal_gate!
      before_action :enforce_restricted_session_guard!
      before_action :enforce_sign_in_selector_gate!
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      def acme_authority_host
        oidc_acme_host
      end

      private

      def verification_setup_redirect_path(pt: nil, scope: nil)
        base_org_verification_setup_url(
          ri: params[:ri], pt: pt || encoded_step_up_pt, scope: scope,
          host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), protocol: "https",
        )
      end

      def auth_credential_ceremony? = true

      # Every HTML action on the Auth host is a sign-in/sign-up ceremony screen or step that never
      # acts on preference authority, so an unusable preference credential is detached instead of
      # ending the request with 401. See PreferenceTransport#handle_unusable_preference_credential!.
      def preference_entry_recovery_action?
        true
      end

      # Direct Auth entrypoints send signed-in operators to Base, which owns dashboard authority.
      def after_login_path
        return oidc_authorization_after_login_path if oidc_authorization_login_challenge.present?

        auth_org_sign_handoff_path(ri: current_region_identifier)
      end

      def after_login_allows_other_host?
        true
      end

      def cross_host_redirect_allowed?
        true
      end

      def auth_service_host
        ENV.fetch("PRIVATE_AUTH_STAFF_URL")
      end

      # A protected Auth page hands sign-in off to the Base neutral /sign entry, whose POST issues the
      # admission back into Auth. The Auth origin's own /sign/in is never the target: the Jump
      # gateway refuses an internal rt whose destination origin equals its issuer
      # (adr/secure-jump-link-redirector.md). The Base origin comes from the boot host registry.
      def sign_in_url_with_pt(_return_to)
        base_org_sign_show_url(
          ri: params[:ri],
          host: Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host,
          protocol: "https",
        )
      end

      def base_authority_host
        ENV.fetch("PUBLIC_BASE_STAFF_URL")
      end

      def oidc_authorization_after_login_path
        auth_org_sign_oidc_handoff_path(
          ri: current_region_identifier,
          protocol: URI.parse(OidcIssuer.absolute_url(auth_service_host)).scheme,
        )
      end
    end
  end
end
