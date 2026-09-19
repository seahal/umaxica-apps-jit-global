# typed: false
# frozen_string_literal: true

require "omniauth_openid_connect"

module OmniAuth
  module Strategies
    # Umaxica-specific Microsoft Entra ID strategy, subclassing the generic
    # omniauth_openid_connect strategy.
    #
    # Single tenant by design: the org surface federates exactly one Entra
    # tenant (the company's own). Tenant id, client id, and client secret are
    # read from Rails credentials at boot in config/initializers/omniauth.rb,
    # the same way the app surface configures Google and Apple.
    #
    # What the base strategy already provides and is intentionally NOT
    # reimplemented here: state generation/consumption, nonce generation, and
    # PKCE S256 verifier/challenge handling (session['omniauth.state'],
    # 'omniauth.nonce', 'omniauth.pkce.verifier']).
    #
    # What this subclass adds on top, and why the base strategy cannot cover it:
    # - Discovery is disabled and the endpoints are tenant-fixed. `common`,
    #   `organizations` and `consumers` are never used: a tenant-scoped issuer
    #   removes a tenant-confusion surface, and Discovery would only add a
    #   network round trip for endpoints already known from the tenant id.
    # - `verify_id_token!`: the base implementation performs generic OIDC
    #   validation only. This app requires Entra-specific claims (`tid`,
    #   `oid`, `acct`) validated by the existing, already-tested
    #   ExternalSignIn::Providers::EntraId verifier.
    # - `uid`/`info`/`extra`/`credentials`: the base implementation calls the
    #   UserInfo endpoint and exposes raw tokens. Neither is permitted here
    #   (no Graph/UserInfo calls, no raw token in the AuthHash).
    #
    # OmniAuth::Strategy#call dups the strategy instance per request
    # (lib/omniauth/strategy.rb), so per-request ivars set below
    # (@verified_entra_result, @access_token) are not shared across
    # concurrent requests.
    class UmaxicaEntra < OpenIDConnect
      option :name, "entra"
      option :response_type, "code"
      option :response_mode, "query"
      option :scope, [:openid, :profile]
      option :send_nonce, true
      option :send_state, true
      option :require_state, true
      option :pkce, true
      option :discovery, false

      AUTHORIZE_ENDPOINT_PATH_TEMPLATE = "/%s/oauth2/v2.0/authorize"
      TOKEN_ENDPOINT_PATH_TEMPLATE = "/%s/oauth2/v2.0/token"

      # Raised for domain-level (non-OIDC-transport) failures inside nested
      # calls (access_token, verify_id_token!). `fail!` only produces a
      # correct response when it is the direct return value of a phase
      # method (request_phase/callback_phase); calling it from a method
      # nested inside `super`'s call graph does not halt execution, so
      # those nested paths raise instead and are converted to `fail!` at
      # the top of callback_phase, mirroring the base gem's own
      # CallbackError pattern.
      class Error < StandardError
        attr_reader :reason

        def initialize(reason)
          @reason = reason
          super(reason.to_s)
        end
      end

      def request_phase
        return fail!(:provider_unavailable) unless entra_start_available?

        configure_tenant_endpoints!
        super
      end

      def callback_phase
        configure_tenant_endpoints!
        super
      rescue Error => e
        fail!(e.reason)
      end

      # Overrides the base gem's token exchange for two reasons: to consume the
      # PKCE verifier explicitly (the base gem does not send one for this
      # configuration), and to run the strict Entra ID token verifier instead
      # of the base gem's generic OIDC checks.
      #
      # Client authentication is `client_secret_post`: rack-oauth2 has no named
      # branch for it, so any client_auth_method outside its recognized set
      # falls through to the `else` in Client#authenticated_context_from, which
      # merges `client_id`/`client_secret` into the POST body and sets no
      # Authorization header (rack-oauth2 2.3.0 lib/rack/oauth2/client.rb).
      # `:client_secret_post` is passed rather than a placeholder so the intent
      # is readable, and
      # test/contracts/omniauth_entra_token_request_contract_test.rb pins the
      # resulting request shape against a rack-oauth2 upgrade changing it.
      #
      # Entra accepts client_secret_post at the v2.0 token endpoint and it keeps
      # the credential in one place instead of a separately-encoded header.
      # The secret comes from the client options configured at boot from Rails
      # credentials; no secret is stored in the database.
      def access_token
        return @access_token if defined?(@access_token) && @access_token

        verifier = session.delete("omniauth.pkce.verifier")
        raise Error, :pkce_verifier_missing if verifier.blank?

        @access_token = client.access_token!(
          scope: options.scope,
          client_auth_method: :client_secret_post,
          code_verifier: verifier,
        )
        verify_id_token!(@access_token.id_token)
        @access_token
      end

      def verify_id_token!(id_token)
        raise Error, :missing_id_token if id_token.blank?

        @verified_entra_result = ExternalSignIn::Providers::EntraId.new(
          id_token: id_token,
          expected_nonce: stored_nonce,
          expected_tenant_id: configured_tenant_id,
          client_id: configured_client_id,
        ).call
      rescue ExternalSignIn::Providers::EntraId::VerificationError => e
        raise Error, e.reason
      end

      def uid
        "#{verified_entra_result.tenant_id}:#{verified_entra_result.entra_object_id}"
      end

      # Plain method overrides, not the `info do ... end` block DSL: the base
      # gem's info/extra/credentials macros MERGE every ancestor's block
      # (OmniAuth::Strategy.compile_stack walks self.class.ancestors), so a
      # block override here would still additionally evaluate the base
      # OpenIDConnect class's blocks -- which call `user_info` (UserInfo
      # endpoint) and expose raw tokens. A plain method definition shadows
      # the base method entirely, the same way `uid` above does.
      def info
        {}
      end

      def extra
        {
          raw_info: {
            "tid" => verified_entra_result.tenant_id,
            "oid" => verified_entra_result.entra_object_id,
            "iss" => verified_entra_result.evidence_issuer,
            "sub" => verified_entra_result.evidence_subject,
          },
        }
      end

      # No raw id_token/access_token/refresh_token in the AuthHash.
      def credentials
        {}
      end

      private

      attr_reader :verified_entra_result

      # Parity with the legacy Auth::Org::Sign::In::Entra::AuthorizationsController:
      # the request phase must respect the same surface-policy and
      # provider-availability (:social_ceremony_org_entra Flipper feature) gate, or a
      # provider-disable during an incident would only stop the callback,
      # not new ceremonies.
      def entra_start_available?
        ExternalAuthentication::ProviderSurfacePolicy.new.allowed?(
          surface: "org", provider: "entra",
          operation: "login",
        ) &&
          ExternalAuthentication::ProviderAvailabilityFactory.current
            .start_decision(provider: "entra", operation: "login", context: {}).state == :enabled
      rescue Redis::BaseError
        false
      end

      def configured_tenant_id
        ExternalAuthentication::ProviderRegistry.tenant_id("entra")
      end

      def configured_client_id
        ExternalAuthentication::ProviderRegistry.audience("entra")
      end

      # The tenant is fixed, so these could be set once at boot. They are
      # applied per request because `options` is the class-level default hash
      # that OmniAuth dups per request; deriving them here keeps a credential
      # rotation from requiring a redeploy and keeps the issuer used for
      # verification and the endpoints used for redirection from drifting
      # apart.
      def configure_tenant_endpoints!
        tenant = configured_tenant_id

        options.issuer = ExternalAuthentication::ProviderRegistry.issuer_for("entra")
        options.client_options.identifier = configured_client_id
        options.client_options.scheme = "https"
        options.client_options.host = "login.microsoftonline.com"
        options.client_options.port = 443
        options.client_options.authorization_endpoint = format(AUTHORIZE_ENDPOINT_PATH_TEMPLATE, tenant)
        options.client_options.token_endpoint = format(TOKEN_ENDPOINT_PATH_TEMPLATE, tenant)
        options.client_options.redirect_uri = ExternalAuthenticationEntraRedirectUri.call
      end
    end
  end
end

OmniAuth.config.add_camelization("umaxica_entra", "UmaxicaEntra")
