# typed: false
# frozen_string_literal: true

module Visa
  module App
    # Shared protocol lifecycle for this realm's authorization and continuation endpoints.
    # Concrete endpoints declare their own authentication mode and public action.
    class AuthorizationBaseController < ::Visa::App::AuthorityController
      include ::OauthAuthorizeRateLimit
      include ::OauthAuthorizeRequestSizeLimit
      include ::OidcAuthorizationResultPost
      include ::OidcAuthorizationRequestErrors

      abstract!

      AUTHENTICATION_MODE = :deny_all

      # Protocol redirects retain the request as sent rather than canonicalizing its region.
      skip_before_action :set_region, raise: false

      private :show, :create

      private

      def oidc_result_surface = "app"

      def authorization_session_sufficient?
        return false unless logged_in?

        prompt = OidcAuthorizeRequestResolver.normalize_prompt(authorize_params[:prompt])
        return false if %w(login create).include?(prompt)

        max_age = @validated_client&.max_age
        return true if max_age.nil?

        authentication_event_at = current_authentication_event_at
        authentication_event_at.present? && Time.current <= authentication_event_at + max_age.seconds
      end

      def validate_authorization_request!(params_hash = authorize_params)
        @validated_client = OidcAuthorizeRequestResolver.call(
          params: params_hash, resource: current_client, resource_type: resource_type,
        )
      end

      def issue_authorization_code!(resource, params_hash: authorize_params, authentication_event_at: nil,
                                    session_token: current_session, auth_method: nil, acr: nil,
                                    authorization_transaction_ref: nil)
        result = ::OidcAuthorizeCoordinator.call(
          params: params_hash,
          resource: resource,
          session_token: session_token,
          auth_method: auth_method || Actor.authn.amr.first,
          acr: acr || Actor.authn.acr,
          authentication_event_at: authentication_event_at || current_authentication_event_at,
          authorization_transaction_ref: authorization_transaction_ref,
        )

        if result.success?
          # Cross-host RP callbacks follow the signed Jump contract.
          redirect_to_same_origin_or_jump_url(
            result.redirect_url,
            status: (request.post? || @oidc_continuation_request) ? :see_other : :found,
          )
        else
          render json: { error: result.error, error_description: result.error_description },
                 status: :bad_request
        end
      end

      def start_authorization_ceremony!
        base_browser_nonce = base_admission_browser_nonce_for_request!
        issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
          surface: "app", intent: authorization_intent, params: authorize_params,
          base_browser_nonce:, base_token: current_session_token,
          restart_of: params[:restart_of],
        )
        sign_url =
          if authorization_intent == "sign_up"
            auth_app_sign_up_sentry_url(
              ri: params[:ri],
              host: oidc_sign_host,
              protocol: oidc_sign_protocol,
              entry_ref: issuance.handoff.reference,
            )
          else
            auth_app_sign_in_sentry_url(
              ri: params[:ri],
              host: oidc_sign_host,
              protocol: oidc_sign_protocol,
              entry_ref: issuance.handoff.reference,
            )
          end
        # The ceremony start is a local POST (D-82); 303 keeps the cross-host hop a GET.
        redirect_to_jump_url(sign_url, status: :see_other)
      end

      def resume_authorization!(transaction, result_generation: nil)
        decision_time = transaction.class.database_now
        return render_invalid_authorization_transaction("authorization transaction expired") if
          transaction.login_challenge_expired?(now: decision_time) || transaction.expired?(now: decision_time)
        return render_invalid_authorization_transaction("authorization transaction is not ready") unless
          transaction.authenticated? || (transaction.consumed? && transaction.base_finalized_at.present?)

        resource = Client.find_by!(public_id: transaction.actor_ref)
        finalization = finalize_authorization_transaction!(
          resource, transaction, result_generation: result_generation,
        )
        return redirect_to_session_limitation! if finalization[:status] == :session_limit_pending
        return render(
          json: { error: "invalid_request", error_description: "login_failed" },
          status: :bad_request,
        ) unless finalization[:status] == :success

        if transaction.secret_sign_in_flow_id
          secret_flow = ClientSignInFlow.find(transaction.secret_sign_in_flow_id)
          credential = ClientSecretCredential.find_by!(
            client_id: resource.id, claim_sign_in_flow_ref: secret_flow.public_id,
          )
          ClientSecretClaimFinalizer.call!(
            credential: credential, purge_after: ClientSecretLifetimesValue.purge_delay,
          )
        end

        issue_authorization_code!(
          resource,
          params_hash: transaction.authorize_params,
          authentication_event_at: transaction.authenticated_at,
          session_token: current_session,
          auth_method: transaction.auth_method,
          acr: transaction.acr,
          authorization_transaction_ref: transaction.transaction_id,
        )
      end

      def render_invalid_authorization_transaction(description)
        render json: { error: "invalid_request", error_description: description }, status: :bad_request
      end

      def finalize_authorization_transaction!(resource, transaction, result_generation: nil)
        resource.class.connection_class_for_self.connected_to(role: :writing) do
          resource.with_lock do
            transaction.finalize_base!(result_generation: result_generation) do |locked, _finalization_time|
              next { status: :login_failed } if locked.base_finalized_at.present?

              login_result = login_for_oidc(resource, locked)
              next login_result unless login_result[:status] == :success

              { status: :success, browser_session_ref: current_session.public_id }
            end
          end
        end
      end

      # Auth recorded only credential evidence; the root login is established
      # here, at the Visa authority, through the final issuance boundary. The
      # cooldown and the session limit are checked at this commit.
      def login_for_oidc(resource, transaction)
        secret_options =
          if transaction.secret_sign_in_flow_id
            unless transaction.auth_method == "passcode"
              raise AuthenticationBase::SignInFlowIssuanceRejected, "Secret OIDC authentication method mismatch"
            end

            flow = ClientSignInFlow.find(transaction.secret_sign_in_flow_id)
            flow.with_lock do
              return { status: :login_failed } if flow.sign_in_failed? ||
                flow.expired?(ClientSignInFlow.database_now)

              unless flow.sign_in_primary_pending? || flow.sign_in_guardrail_pending? ||
                  flow.sign_in_checkpoint_pending? || flow.sign_in_selector_pending? ||
                  flow.sign_in_session_issuance_pending?
                raise FlowInvalidTransition, "Secret OIDC handoff is not ready"
              end
            end
            { sign_in_flow: flow, established_authentication_method: "secret" }
          else
            {}
          end
        ActiveRecord::Base.connected_to(role: :writing) do
          result = log_in(
            resource,
            establishment: :root_login,
            record_login_audit: true,
            token_kind_id: "BROWSER_WEB",
            require_totp_check: false,
            audit_context: { oidc_client_id: transaction.client_id },
            authentication_event_at: transaction.authenticated_at,
            established_authentication_method: established_authentication_method_for(transaction.auth_method),
            oidc_authorization_transaction: transaction,
            **secret_options,
          )
          result
        end
      end

      def redirect_to_session_limitation!
        redirect_to(visa_app_sign_in_limitation_path(ri: params[:ri]), status: :see_other)
      end

      # D06 Switch target page on Auth for a fresh admission of the same parent.
      def authorization_switch_url(target:, entry_ref:)
        case target
        when "sign_in"
          auth_app_sign_in_sentry_url(ri: params[:ri], host: oidc_sign_host, protocol: oidc_sign_protocol, entry_ref:)
        when "sign_up"
          auth_app_sign_up_sentry_url(ri: params[:ri], host: oidc_sign_host, protocol: oidc_sign_protocol, entry_ref:)
        else
          raise ArgumentError, "unsupported switch target: #{target.inspect}"
        end
      end

      def authorization_intent
        prompt = OidcAuthorizeRequestResolver.normalize_prompt(authorize_params[:prompt])
        return "sign_up" if prompt == "create"
        return "authentication" if first_party_browser_rp?

        "sign_in"
      end

      def first_party_browser_rp?
        AuthBoundaryAuthorityMap.first_party_rp_client_ids.include?(authorize_params[:client_id].to_s)
      end

      # The client and redirect_uri were validated above, so the protocol error is returned
      # to the RP callback (OIDC Core 1.0 section 3.1.2.6) instead of being rendered here.
      def redirect_login_required!
        # Cross-host RP callbacks follow the signed Jump contract.
        redirect_to_same_origin_or_jump_url(
          ::OidcAuthorizeCoordinator.error_redirect_url(
            redirect_uri: authorize_params[:redirect_uri].to_s,
            resource_type: resource_type,
            error: "login_required",
            state: authorize_params[:state],
          ),
        )
      end

      def prompt_none_requested?
        OidcAuthorizeRequestResolver.normalize_prompt(authorize_params[:prompt]) == "none"
      end

      def oidc_sign_protocol
        URI.parse(OidcIssuer.absolute_url(oidc_sign_host)).scheme
      end

      def authorize_params
        # `slice` first: this reads a fixed set of keys and ignores everything else the
        # request carries (`ri`, the Turnstile token). Permitting without narrowing would
        # report those as unpermitted, which they are not - they are simply not ours.
        keys = %i(
          response_type client_id redirect_uri state
          code_challenge code_challenge_method scope nonce prompt max_age
        )
        params.slice(*keys).permit(*keys)
      end
    end
  end
end
