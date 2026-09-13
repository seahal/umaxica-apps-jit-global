# typed: false
# frozen_string_literal: true

module Auth
  module Com
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::WebauthnSurfaceDeclarable

      webauthn_surface :com
      include ::Session
      include ::PreferenceGlobal
      include ::PreferenceAdoption
      include ::SignSignupObservability
      include ::AuthenticationVisitor
      include ::SignErrorResponses
      include ::SessionLimitGate
      include ::AuthorizationAudit
      include ::AuthenticationCredentialInventoryReader
      include ::AuthorizationVisitor
      include ::VerificationVisitor
      include ActionPolicy::Controller
      include ::OidcSsoInitiator
      include ::RestrictedSessionGuard
      include SignComRouteAliasHelper
      include ::ActorSupport
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      layout "auth/com/application"

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: JitHostOriginEnv.trusted_origins(
                             ENV.fetch("PRIVATE_AUTH_CORPORATE_URL"),
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
                    :signed_pt_param, :current_visitor, :logged_in?, :active_visitor?, :logged_in_visitor?,
                    :current_region_identifier
      helper_method :acme_authority_host, :base_authority_host

      helper ::Auth::Com::ApplicationHelper
      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays a side-effect-free helper; the limit and its numeric
      # value are declared here on the inheriting controller.
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "auth_com_default_web",
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
      before_action :enforce_sign_in_selector_gate!
      before_action :enforce_required_telephone_registration!
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      def acme_authority_host
        oidc_acme_host
      end

      class << self
        def local_prefixes
          prefixes = Array(super)
          app_prefix = controller_path.sub("/com/", "/app/")
          prefixes.include?(app_prefix) ? prefixes : prefixes + [app_prefix]
        end
      end

      private

      def actor_staff?
        false
      end

      def current_verification_actor
        current_visitor
      end

      def verification_model
        VisitorVerification
      end

      def verification_token_foreign_key
        :visitor_token_id
      end

      def identity_email_model
        VisitorEmail
      end

      def identity_telephone_model
        VisitorTelephone
      end

      def identity_from_email_record(record)
        record&.visitor
      end

      def identity_from_telephone_record(record)
        record&.visitor
      end

      def actor_verification_path(attrs = {})
        auth_com_verification_path(attrs)
      end

      def verification_redirect_path(pt: nil, scope_override: nil)
        attrs = { ri: params[:ri], pt: pt }
        scope = scope_override.to_s.presence || verification_scope.to_s.presence
        attrs[:scope] = scope if scope
        auth_com_verification_path(attrs)
      end

      def verification_setup_redirect_path(pt: nil)
        new_auth_com_verification_setup_path(ri: params[:ri], pt: pt || encoded_step_up_pt)
      end

      def after_login_path
        return oidc_authorization_after_login_path if oidc_authorization_login_challenge.present?

        base_com_dashboard_url(ri: current_region_identifier, host: base_authority_host)
      end

      def after_login_allows_other_host?
        true
      end

      def enforce_required_telephone_registration!
        return unless request.format.html?
        return unless current_visitor&.respond_to?(:verified_telephone?)
        return if current_visitor.verified_telephone?
        return if telephone_registration_allowed_path?

        redirect_to_jump_url(
          new_base_com_identity_telephones_registration_url(
            ri: params[:ri], host: base_authority_host,
            protocol: "https",
          ),
        )
      end

      def telephone_registration_allowed_path?
        # `auth/com/sign/outs` must stay reachable even when telephone
        # registration is required so a user can cancel the current ceremony
        # or abort a pending logout before they are forced into registration.
        allowed = [
          "base/com/identity/telephones/registrations",
          "auth/com/sign/outs",
        ]
        allowed.include?(controller_path)
      end

      def cross_host_redirect_allowed?
        true
      end

      def oidc_client_id
        "sign-rp"
      end

      def oidc_sign_host
        ENV.fetch("PRIVATE_AUTH_CORPORATE_URL")
      end

      def oidc_acme_host
        ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
      end

      def oidc_base_authority_host
        oidc_acme_host
      end

      def base_authority_host
        ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
      end

      def oidc_authorization_login_challenge
        session[:oidc_authorization_login_challenge]
      end

      def oidc_authorization_after_login_path
        challenge = oidc_authorization_login_challenge
        result =
          OidcAuthorizationTransactionCoordinator.register_result!(
            surface: "com",
            login_challenge: challenge,
            actor: current_resource,
            session_ref: current_session_public_id,
            auth_method: Array(Actor.authn.access_claims&.dig("amr")).first || "unknown",
            acr: Actor.authn.access_claims&.dig("acr"),
          )
        result.resume_url
      ensure
        session.delete(:oidc_authorization_login_challenge)
      end
    end
  end
end
