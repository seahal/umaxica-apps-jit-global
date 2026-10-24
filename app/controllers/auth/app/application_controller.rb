# typed: false
# frozen_string_literal: true

module Auth
  module App
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::DefaultNoStore
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
      include ::AuthCeremonyContext
      include ::AuthAdmissionCurfewGate
      include ::SignInPathRefusal
      include ::SignEntrySentryEnforcement
      include SurfaceRouteAliasHelper
      include ::ActorSupport
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      AUTH_CEREMONY_SURFACE = "app"

      layout "auth/app/application"

      allow_browser versions: :modern

      # Rails validates Origin and Fetch Metadata first; require its session-bound token before surface callbacks.
      prepend_before_action :require_authenticity_token_for_unsafe_request!
      protect_from_forgery using: :header_or_legacy_token, with: :exception, prepend: true
      ensure_fqdn_gate_first!
      prepend_before_action :apply_default_no_store

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from AuthenticationBase::LoginCooldownError, with: :render_login_cooldown
      rescue_from AlreadyAuthenticatedError, with: :render_sign_in_unavailable_while_authenticated
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      rescue_from SignUpCycleLocator::OwnershipMismatch, with: :render_sign_up_ownership_mismatch
      helper_method :current_actor, :current_account, :current_session_public_id,
                    :signed_pt_param, :current_client, :logged_in?, :active_client?, :logged_in_client?,
                    :current_region_identifier
      helper_method :acme_authority_host, :base_rp_host

      # NOTE: Order matters (dependencies rely on this sequence)
      # Jump-return handling runs before rate limiting so that cross-surface
      # navigations arriving via jump.umaxica.net can strip the rt parameter
      # and redirect before consuming a rate-limit slot.
      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays an effect-free helper; the limit and its numeric
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
      before_action :enforce_admission_curfew!
      before_action :enforce_sign_entry_sentry!
      before_action :set_region
      before_action :transparent_refresh_access_token, unless: -> { request.format.json? }
      before_action :set_current_actor
      before_action :apply_localization_preferences
      before_action :set_locale
      before_action :set_timezone
      before_action :set_color_theme
      before_action :enforce_withdrawal_gate!
      before_action :enforce_sign_in_selector_gate!
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      private

      def require_authenticity_token_for_unsafe_request!
        return unless protect_against_forgery?
        return if request.get? || request.head? || verified_query_request?
        return if any_authenticity_token_valid?

        instrument_unverified_request
        handle_unverified_request
      end

      def sign_in_phase_binding_surface = "app"

      def auth_credential_ceremony? = true

      # Every HTML action on the Auth host is a sign-in/sign-up ceremony screen or step that never
      # acts on preference authority, so an unusable preference credential is detached instead of
      # ending the request with 401. See PreferenceTransport#handle_unusable_preference_credential!.
      def preference_entry_recovery_action?
        true
      end

      # Direct Auth entrypoints send signed-in clients to Base, which owns dashboard authority.
      def after_login_path
        return oidc_authorization_after_login_path if oidc_authorization_login_challenge.present?

        # The Local completion is removed (D-60); without an OIDC login challenge the browser returns
        # to its surface's Base RP entry.
        base_app_sign_show_url(
          ri: current_region_identifier, host: Rails.configuration.x.boot_config.fetch(:hosts).base_service.host,
          protocol: "https",
        )
      end

      def after_login_allows_other_host?
        true
      end

      def cross_host_redirect_allowed?
        true
      end

      def verification_setup_redirect_path(pt: nil, scope: nil)
        base_app_verification_setup_url(
          ri: params[:ri], pt: pt || encoded_step_up_pt, scope: scope,
          host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), protocol: "https",
        )
      end

      def auth_service_host
        ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      end

      def oidc_authorization_after_login_path
        auth_app_sign_oidc_handoff_path(
          ri: current_region_identifier,
          protocol: URI.parse(OidcIssuer.absolute_url(auth_service_host)).scheme,
        )
      end

      def acme_authority_host
        base_rp_host
      end

      # A protected Auth page hands sign-in off to the Base neutral /sign entry, whose POST issues the
      # admission back into Auth. The Auth origin's own /sign/in is never the target: the Jump
      # gateway refuses an internal rt whose destination origin equals its issuer
      # (adr/secure-jump-link-redirector.md). The Base origin comes from the boot host registry.
      def sign_in_url_with_pt(_return_to)
        base_app_sign_show_url(
          ri: params[:ri],
          host: Rails.configuration.x.boot_config.fetch(:hosts).base_service.host,
          protocol: "https",
        )
      end

      def base_rp_host
        ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      end

      def visa_authority_host
        Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host
      end

      # WU-06/WU-13: the post-curfew exit uses Visa's continuation resource. The Base RP
      # browser binding is verified there before the registered redirect receives access_denied.
      def curfew_exit_url(cancellation_ref:, transaction_ref:)
        visa_app_oidc_cancellation_url(
          cancellation_ref:, transaction_ref:, ri: params[:ri],
          host: visa_authority_host, protocol: "https",
        )
      end
    end
  end
end
