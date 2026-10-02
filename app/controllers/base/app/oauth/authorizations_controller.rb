# typed: false
# frozen_string_literal: true

module Base
  module App
    module Oauth
      class AuthorizationsController < Base::App::ApplicationController
        include ::OauthAuthorizeRateLimit
        include ::OauthAuthorizeRequestSizeLimit
        include ::OidcAuthorizationResultPost

        AUTHENTICATION_MODE = :open
        OIDC_RESULT_TRUSTED_ORIGINS = JitHostOriginEnv.trusted_origins(
          ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
        ).freeze
        declare_authentication_mode! :open

        protect_from_forgery using: :header_or_legacy_token,
                             trusted_origins: OIDC_RESULT_TRUSTED_ORIGINS,
                             with: :exception,
                             only: :create,
                             if: -> { params[:result].present? }
        skip_before_action :set_region, raise: false
        before_action :enforce_oauth_authorize_request_size!, only: :show

        def show
          validate_authorization_request!

          # A browser already authenticated here may not start a new Sign, even for an RP that has
          # no session yet; there is no SSO success branch
          # (adr/sign-neutral-entry-and-logout-target-authorization.md). The Auth result POST
          # (`create`) is the only continuation that issues a code.
          if logged_in?
            render_sign_in_unavailable_while_authenticated
          elsif prompt_none_requested?
            redirect_login_required!
          else
            start_authorization_ceremony!
          end
        rescue OidcAuthorizeRequestResolver::InvalidScope => e
          render json: { error: "invalid_scope", error_description: e.message }, status: :bad_request
        # OidcAuthorizeRequestResolver raises ArgumentError with spec-level request
        # descriptions ("scope must include openid", "state is required"), and the registry
        # errors are equally spec-defined. RFC 6749 section 4.1.2.1 expects these in
        # error_description and they disclose nothing about stored data.
        rescue ArgumentError, OidcClientRegistry::ClientNotFound, OidcClientRegistry::InvalidRedirectUri => e
          render json: { error: "invalid_request", error_description: e.message }, status: :bad_request
        # RecordNotFound is different: its message names the model and the primary key that
        # was looked up. The client gets a fixed description; the detail goes to the log.
        rescue BaseAuthAdmissionCoordinator::Denied
          render json: { error: "invalid_request", error_description: "invalid authorization request" },
                 status: :bad_request
        rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError => e
          Rails.logger.error(
            JitLogEvent.format(
              "oidc.authorize.backend_failure",
              surface: oidc_result_surface,
              error_class: e.class.name,
              request_id: request.request_id,
            ),
          )
          render json: {
            error: "temporarily_unavailable",
            error_description: I18n.t("errors.rate_limit.backend_unavailable"),
          }, status: :service_unavailable
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.info(
            JitLogEvent.format(
              "oidc.authorize.invalid_request",
              error_class: e.class.name,
              oidc_client_id: params[:client_id].to_s.presence,
            ),
          )
          render json: { error: "invalid_request", error_description: "invalid authorization request" },
                 status: :bad_request
        end

        private

        def oidc_result_surface = "app"

        def validate_authorization_request!(params_hash = authorize_params)
          @validated_client = OidcAuthorizeRequestResolver.call(
            params: params_hash, resource: current_client, resource_type: resource_type,
          )
        end

        def issue_authorization_code!(resource, params_hash: authorize_params, authentication_event_at: nil,
                                      session_token: current_session, auth_method: nil, acr: nil,
                                      authorization_transaction_ref: nil)
          access_claims = Actor.authn.access_claims
          result = ::OidcAuthorizeCoordinator.call(
            params: params_hash,
            resource: resource,
            session_token: session_token,
            auth_method: auth_method || Array(access_claims&.dig("amr")).first,
            acr: acr || access_claims&.dig("acr"),
            authentication_event_at: authentication_event_at || current_authentication_event_at,
            authorization_transaction_ref: authorization_transaction_ref,
          )

          if result.success?
            redirect_to_jump_url(result.redirect_url)
          else
            render json: { error: result.error, error_description: result.error_description },
                   status: :bad_request
          end
        end

        def start_authorization_ceremony!
          issuance =
            OidcAuthorizationTransactionCoordinator.issue!(
              surface: "app",
              intent: authorization_intent,
              params: authorize_params,
            )
          handoff = BaseAuthAdmissionCoordinator.issue_handoff!(transaction: issuance.transaction)
          sign_url =
            if authorization_intent == "sign_up"
              auth_app_sign_up_url(
                ri: params[:ri],
                host: oidc_sign_host,
                protocol: oidc_sign_protocol,
                transaction_ref: handoff.reference,
              )
            else
              auth_app_sign_in_url(
                ri: params[:ri],
                host: oidc_sign_host,
                protocol: oidc_sign_protocol,
                transaction_ref: handoff.reference,
              )
            end
          redirect_to_jump_url(sign_url)
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
          return redirect_to_session_limitation!(
            resource,
            transaction,
          ) if finalization[:status] == :session_limit_hard_reject ||
            finalization[:session_management_required]
          return render(
            json: { error: "invalid_request", error_description: "login_failed" },
            status: :bad_request,
          ) unless finalization[:status] == :success

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
          transaction.finalize_base!(result_generation: result_generation) do |locked, _finalization_time|
            if locked.base_finalized_at.present?
              token_record = find_browser_session_for_oidc(resource, locked.browser_session_ref)
              next { status: :login_failed } unless token_record

              reissue_login_credentials_for_existing_session(
                resource: resource,
                token_record: token_record,
                token_kind_id: "BROWSER_WEB",
                authentication_event_at: locked.authenticated_at,
              ).merge(browser_session_ref: locked.browser_session_ref)
            else
              login_result = login_for_oidc(resource, locked)
              next login_result if login_result[:status] == :session_limit_hard_reject ||
                login_result[:session_management_required]
              next login_result unless login_result[:status] == :success

              { status: :success, browser_session_ref: current_session.public_id }
            end
          end
        end

        def login_for_oidc(resource, transaction)
          ActiveRecord::Base.connected_to(role: :writing) do
            log_in(
              resource,
              record_login_audit: false,
              token_kind_id: "BROWSER_WEB",
              require_totp_check: false,
              audit_context: { oidc_client_id: transaction.client_id },
              bootstrap_actor: false,
              skip_login_cooldown: true,
              authentication_event_at: transaction.authenticated_at,
            )
          end
        end

        def redirect_to_session_limitation!(resource, transaction)
          issuance =
            ClientSessionLimitResolutionTransaction.issue_for_oidc!(
              actor: resource,
              oidc_transaction: transaction,
              audit_context: {
                client_id: transaction.client_id,
                intent: transaction.intent,
              },
            )
          redirect_to(
            base_app_sign_in_limitation_path(resolution_challenge: issuance.challenge),
            status: :see_other,
          )
        end

        def authorization_intent
          return "authentication" if first_party_browser_rp?

          (params[:screen_hint].to_s == "signup") ? "sign_up" : "sign_in"
        end

        def first_party_browser_rp?
          AuthBoundaryAuthorityMap.first_party_rp_client_ids.include?(authorize_params[:client_id].to_s)
        end

        # The client and redirect_uri were validated above, so the protocol error is returned
        # to the RP callback (OIDC Core 1.0 section 3.1.2.6) instead of being rendered here.
        def redirect_login_required!
          redirect_to_jump_url(
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
            code_challenge code_challenge_method scope nonce screen_hint prompt max_age
          )
          params.slice(*keys).permit(*keys)
        end
      end
    end
  end
end
