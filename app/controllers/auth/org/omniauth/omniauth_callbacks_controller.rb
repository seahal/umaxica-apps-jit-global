# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Omniauth
      # OmniAuth callback boundary for the org (staff) surface.
      #
      # Routes:
      #   GET /social/entra/callback -> #omniauth
      #   GET /social/entra/failure  -> #failure
      #
      # The strategy (lib/omniauth/strategies/umaxica_entra.rb) already
      # performed PKCE/state/nonce validation and Entra ID token verification
      # before this controller runs; `request.env["omniauth.auth"]` carries
      # only verified, minimal claims (tid, oid, iss, sub -- never raw tokens,
      # never email/UPN/name).
      #
      # This controller is Rails glue only: it normalizes the AuthHash through
      # the same ExternalAuthentication adapter interface the app surface uses
      # for Google and Apple and delegates identity lookup to
      # ExternalSignIn::OrgEntraResolver (no JIT provisioning).
      # See adr/org-entra-id-sign-in-boundary.md.
      #
      # Entra is the first stage of Normal org sign-in, not the whole of it. A
      # successful callback establishes no session: it records which Operator
      # Entra selected in a short-lived, purpose-bound pending transaction and
      # hands the browser to the passkey stage, which (or, for a lost passkey,
      # the secret stage) completes the ceremony. See
      # docs/security/org-emergency-access.md and OrgNormalSignInTransaction.
      class OmniauthCallbacksController < ::Auth::Org::ApplicationController
        include SessionLimitGate
        include ExternalAuthenticationEndpoint
        include ::OrgNormalSignInTransaction
        include ::AuthenticationModeSwitchGuard

        AUTHENTICATION_MODE = :guest

        # The callback GET is a cross-site redirect from Microsoft; region/
        # localization canonicalization before_actions would otherwise
        # redirect it before the callback is processed (mirrors
        # Auth::App::Omniauth::OmniauthCallbacksController).
        skip_before_action :apply_localization_preferences, only: %i(omniauth failure), raise: false
        skip_before_action :set_region, only: %i(omniauth failure), raise: false

        rate_limit(
          to: 10,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "auth_org_sign_in_entra",
          name: "omniauth_callback_ip_burst",
          store: rate_limit_store,
          only: :omniauth,
          with: -> {
            render_rate_limited(retry_after: 60)
          },
        )

        # The failure endpoint is unauthenticated and reachable without a
        # ceremony, and every request emits a
        # sign.org.authentication.entra.callback_failure event. Its own counter
        # (separate name and scope from the callback limit above) keeps flooding
        # the audit trail from being free, without letting failure traffic
        # consume the callback budget or the reverse -- an attacker must not be
        # able to lock a staff member out of a legitimate callback by hammering
        # /social/entra/failure. 20/minute leaves normal ceremony failures,
        # including retries, well inside the budget.
        rate_limit(
          to: 20,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "auth_org_sign_in_entra_failure",
          name: "omniauth_failure_ip_burst",
          store: rate_limit_store,
          only: :failure,
          with: -> {
            render_rate_limited(retry_after: 60)
          },
        )

        def omniauth
          auth = request.env["omniauth.auth"]
          return render_entra_error(:invalid_callback) unless auth.is_a?(OmniAuth::AuthHash) && auth.provider == "entra"

          unless external_authentication_allowed?(surface: "org", provider: "entra", operation: "login") &&
              external_authentication_callback_available?(provider: "entra", ceremony: {}, context: {})
            return render_entra_error(:provider_unavailable)
          end

          callback = ExternalAuthentication::ProviderAdapterFactory.build(
            provider: "entra",
            audience: ExternalAuthentication::ProviderRegistry.audience("entra"),
          ).call(auth_hash: auth, verified_at: Time.current)
          return render_entra_error(:invalid_callback) if callback.failed?

          resolution = ExternalSignIn::OrgEntraResolver.new(
            tenant_context: callback.principal.tenant_context,
          ).call
          identity = resolution.identity
          operator = resolution.operator

          unless operator&.login_allowed?
            log_entra_failure("operator_not_allowed", operator_id: identity.operator_id)
            return render_entra_error(:operator_not_found)
          end

          return if reject_locked_authentication_method!(identity: identity, operator: operator)

          # The callback is a GET (Entra redirects back with `code`/`state`);
          # the identity timestamp write must not run against a read replica.
          ActiveRecord::Base.connected_to(role: :writing) do
            identity.update!(last_authenticated_at: Time.current)
          end

          start_normal_sign_in_second_stage!(operator: operator, identity: identity)
        rescue ExternalSignIn::IdentityNotFoundError
          render_entra_error(:identity_not_found)
        rescue StandardError => e
          log_entra_failure("internal_error", error_class: e.class.name)
          render_entra_error(:internal_error)
        end

        # GET /social/entra/failure
        # `message` is an unauthenticated request parameter, so it is classified
        # through the same allowlist used for rendering before it reaches the
        # log. Only the classification is retained; the raw parameter is never
        # logged (adr/application-logging-boundary.md). The action carries its
        # own IP rate limit (above), independent of the callback limit.
        def failure
          reason = entra_failure_reason(params[:message].presence || "unknown_error")
          log_entra_failure("omniauth_failure", message: reason)
          render_entra_error(reason)
        end

        private

        def entra_failure_reason(message)
          case message
          when "connection_not_found", "pkce_verifier_missing", "client_assertion_unavailable",
               "missing_id_token", "tenant_not_allowed", "tenant_mismatch"
            message.to_sym
          else
            :entra_error
          end
        end

        def consume_pt!
          @consumed_pt = session.delete(::Auth::Org::Social::SessionsController::PT_SESSION_KEY) \
            unless defined?(@consumed_pt)
          @consumed_pt
        end

        # Provider exception messages can contain response bodies or claim
        # payloads; retain only allowlisted classification metadata
        # (adr/application-logging-boundary.md).
        def log_entra_failure(reason, **payload)
          Rails.logger.warn(
            JitLogEvent.format(
              "sign.org.authentication.entra.callback_failure",
              reason: reason,
              **payload,
            ),
          )
        end

        def render_entra_error(reason)
          @error_reason = reason
          render :error, status: :unprocessable_content, formats: :html
        end

        def reject_locked_authentication_method!(identity:, operator:)
          locked = external_authentication_method_locked?(
            enforcement_case_class: OrgEnforcementCase,
            principal_public_id: operator.public_id,
            authentication_method: "entra",
          )
          return false unless locked

          log_entra_failure("authentication_method_locked", operator_id: identity.operator_id)
          render_entra_error(:authentication_method_locked)
          true
        end

        # Entra identifies the Operator; it does not authenticate the session.
        # The pending transaction is what binds the second stage to this
        # Operator, and it is the only place the second stage will look.
        def start_normal_sign_in_second_stage!(operator:, identity:)
          pt = consume_pt!
          issue_org_normal_sign_in_transaction!(
            operator: operator,
            entra_identity_id: identity.id,
            pt: pt,
            ri: current_region_identifier,
          )

          redirect_to(
            new_auth_org_sign_in_passkey_path(pt: pt, ri: current_region_identifier),
            status: :see_other,
          )
        end
      end
    end
  end
end
