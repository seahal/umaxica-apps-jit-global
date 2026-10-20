# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Oauth
      class AuthorizationsController < Base::Org::AuthorityController
        include ::OpClientAdmissionGate
        include ::OauthAuthorizeRateLimit
        include ::OauthAuthorizeRequestSizeLimit
        include ::OidcAuthorizationResultPost

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        skip_before_action :set_region, raise: false
        before_action :enforce_oauth_authorize_request_size!, only: :show

        def show
          return render_oidc_result_continuation! if params[:result_ref].present? || params[:transaction_ref].present?

          validate_authorization_request!
          return render_client_not_admitted unless op_client_admitted?(authorize_params[:client_id].to_s)

          if authorization_session_sufficient?
            issue_authorization_code!(current_operator)
          elsif prompt_none_requested?
            redirect_login_required!
          else
            render_authorization_ceremony_start!
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

        def oidc_result_surface = "org"

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
            params: params_hash, resource: current_operator, resource_type: resource_type,
          )
        end

        def issue_authorization_code!(resource, params_hash: authorize_params, authentication_event_at: nil,
                                      session_token: current_session, auth_method: nil, acr: nil,
                                      authorization_transaction_ref: nil)
          result = ::OidcAuthorizeCoordinator.call(
            params: params_hash,
            resource: resource,
            session_token: session_token,
            auth_method: auth_method || Array(Actor.authn.access_claims&.dig("amr")).first,
            acr: acr || Actor.authn.access_claims&.dig("acr"),
            authentication_event_at: authentication_event_at || current_authentication_event_at,
            authorization_transaction_ref: authorization_transaction_ref,
          )

          if result.success?
            # base-org-ww's callback shares this origin; Jump refuses that self-loop.
            redirect_to_same_origin_or_jump_url(result.redirect_url, status: request.post? ? :see_other : :found)
          else
            render json: { error: result.error, error_description: result.error_description },
                   status: :bad_request
          end
        end

        def start_authorization_ceremony!
          ensure_base_admission_browser_nonce!
          issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
            surface: "org", intent: authorization_intent, params: authorize_params,
            base_browser_nonce: base_admission_browser_nonce, base_token: current_session_token,
            restart_of: params[:restart_of],
          )
          sign_url =
            if authorization_intent == "sign_up"
              auth_org_sign_up_url(
                ri: params[:ri],
                host: oidc_sign_host,
                protocol: oidc_sign_protocol,
                entry_ref: issuance.handoff.reference,
              )
            else
              auth_org_sign_in_url(
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

          resource = Operator.find_by!(public_id: transaction.actor_ref)
          finalization = finalize_authorization_transaction!(
            resource, transaction, result_generation: result_generation,
          )
          return redirect_to_session_limitation! if finalization[:status] == :session_limit_pending
          if finalization[:status] == :session_limit_conflict
            return render_sign_in_refusal(
              message: finalization[:message], http_status: finalization[:http_status],
              error_code: "session_limit_conflict",
            )
          end
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

        def redirect_to_session_limitation!
          redirect_to(base_org_sign_in_limitation_path(ri: params[:ri]), status: :see_other)
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
        # here, at the Base authority, through the final issuance boundary. The
        # cooldown and the session limit are checked at this commit.
        def login_for_oidc(resource, transaction)
          ActiveRecord::Base.connected_to(role: :writing) do
            log_in(
              resource,
              establishment: :root_login,
              record_login_audit: true,
              token_kind_id: "BROWSER_WEB",
              require_totp_check: false,
              audit_context: { oidc_client_id: transaction.client_id },
              authentication_event_at: transaction.authenticated_at,
              authentication_context: AuthenticationContextValue::NORMAL_KEY,
              established_authentication_method: established_authentication_method_for(transaction.auth_method),
              oidc_authorization_transaction: transaction,
            )
          end
        end

        # Org has no public Sign Up, so a Switch never reaches here (the coordinator refuses it).
        def authorization_switch_url(target:, entry_ref:)
          raise ArgumentError, "Org does not switch to #{target.inspect} (entry #{entry_ref.inspect})"
        end

        def authorization_intent
          return "authentication" if first_party_browser_rp?

          "sign_in"
        end

        def first_party_browser_rp?
          AuthBoundaryAuthorityMap.first_party_rp_client_ids.include?(authorize_params[:client_id].to_s)
        end

        def oidc_sign_protocol
          URI.parse(OidcIssuer.absolute_url(oidc_sign_host)).scheme
        end

        # The client and redirect_uri were validated above, so the protocol error is returned
        # to the RP callback (OIDC Core 1.0 section 3.1.2.6) instead of being rendered here.
        def redirect_login_required!
          # base-org-ww's callback shares this origin; Jump refuses that self-loop.
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
end
