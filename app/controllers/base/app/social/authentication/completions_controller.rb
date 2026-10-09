# typed: false
# frozen_string_literal: true

module Base
  module App
    module Social
      module Authentication
        # GET renders the receiver-local form; POST consumes the server-side result.
        # Consumes the signed social ceremony result posted back from the Auth
        # host and establishes the app session (or enters the sign-up cycle).
        class CompletionsController < ::Base::App::AuthorityController
          include SocialCeremonyParams

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          protect_from_forgery using: :header_or_legacy_token, with: :exception

          def show
            apply_base_browser_continuation_headers!
            provider = social_provider_param
            result_reference = params[:result_ref]
            unless result_reference.is_a?(String) && result_reference.match?(AuthAdmissionBinding::REFERENCE_PATTERN)
              raise ActionController::BadRequest
            end

            render "base/shared/result_continuation", layout: false,
                                                      locals: {
                                                        action_url: "#{request.path}?id=#{CGI.escape(provider)}",
                                                        result_ref: result_reference,
                                                        transaction_ref: nil,
                                                        ri: params[:ri],
                                                      }
          rescue ActionController::BadRequest
            render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
          end

          def create
            apply_base_browser_continuation_headers!
            provider = social_provider_param
            result_reference = params[:result_ref]
            unless result_reference.is_a?(String) && result_reference.match?(AuthAdmissionBinding::REFERENCE_PATTERN)
              raise ActionController::BadRequest
            end

            result_token = SocialCeremonyResultAdapter.new.read(reference: result_reference)
            raise ActionController::BadRequest if result_token.blank?

            # Unverified routing cannot authorize a login or a link. The signup result
            # must also match a redeemed admission before the cryptographic commit.
            payload = IdentitySocialCeremonyContract.decode_untrusted_routing_payload(result_token)
            return reject_social_link_completion!(provider) if payload["operation"].to_s == "link"

            raise ActionController::BadRequest unless payload["operation"].to_s == "signup"

            receipt = IdentitySocialCeremonyFinalCommitter.committed_signup!(
              result_token:, session_ref: payload["session_ref"], surface: "app",
            )
            return redirect_completed_social_signup!(receipt) if receipt

            binding = BaseAuthAdmissionCoordinator.validate_social_result_browser_binding!(
              reference: payload["session_ref"],
              surface: "app",
              provider: SocialIdentifiable.normalize_provider(provider),
              base_browser_nonce: base_admission_browser_nonce,
              base_token: current_session_token,
            )

            commit = IdentitySocialCeremonyFinalCommitter.call!(
              result_token: result_token,
              actor: nil,
              session_ref: binding.entry_ref,
              surface: "app",
              ip_address: request.remote_ip,
              user_agent: request.user_agent,
            )
            return render_social_completion_failure if commit.is_a?(FlowTransitionResult)

            raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless commit.user

            complete_admitted_social_signup!(commit, provider, binding)
          rescue BaseAuthAdmissionCoordinator::Denied, IdentitySocialCeremonyContract::Error,
                 ActionController::ParameterMissing,
                 ActionController::BadRequest, ActiveRecord::RecordNotFound
            render_social_completion_failure
          rescue SocialAuth::BaseError => e
            render_social_completion_failure(message: e.message)
          rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
            render_social_completion_failure(
              message: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable,
            )
          end

          public :create

          private

          def reject_social_link_completion!(provider)
            redirect_to_surface_url(
              sign_social_settings_url_for(provider),
              status: :see_other,
            )
          end

          def sign_social_settings_url_for(provider)
            if SocialIdentifiable.normalize_provider(provider) == "apple"
              auth_app_settings_apple_url(
                ri: params[:ri],
                host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                protocol: "https",
              )
            else
              auth_app_settings_google_url(
                ri: params[:ri],
                host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                protocol: "https",
              )
            end
          end

          def redirect_completed_social_signup!(commit)
            binding = BaseAuthAdmissionCoordinator.validate_completed_social_signup_browser_binding!(
              commit:,
              surface: "app",
              base_browser_nonce: base_admission_browser_nonce,
              base_token: current_session_token,
              allow_incomplete: true,
            )
            unless binding.admitted_auth_ceremony_session.completed?
              return complete_admitted_social_signup!(commit, commit.identity.provider, binding)
            end

            flow = ClientSignUpFlow.find_by!(public_id: commit.result["actor_ref"])
            reference = flow.completed_requirements.fetch("social_signup").fetch("completion_ref")
            destination =
              if binding.parent_kind == :authorization_transaction
                raise IdentitySocialCeremonyContract::Error, "social completion reference is invalid" unless
                  reference.is_a?(String) && reference.match?(AuthAdmissionBinding::REFERENCE_PATTERN)

                base_app_oauth_authorization_path(
                  result_ref: reference,
                  transaction_ref: binding.authorization_transaction.transaction_id,
                  ri: params[:ri],
                )
              else
                parent = binding.sign_in_flow
                raise IdentitySocialCeremonyContract::Error, "social completion parent is invalid" unless
                  reference.is_a?(String) && reference == parent.public_id

                parent.sign_in_session_issuance_pending? ? social_session_limitation_path :
                  base_app_dashboard_path(ri: params[:ri])
              end
            redirect_to(destination, status: :see_other)
          end

          def record_social_signup_completion!(commit, reference)
            AppTicketRecord.connected_to(role: :writing) do
              flow = ClientSignUpFlow.find_by!(public_id: commit.result["actor_ref"])
              flow.with_cycle_lock do
                evidence = flow.completed_requirements.fetch("social_signup")
                flow.update!(
                  completed_requirements: flow.completed_requirements.merge(
                    "social_signup" => evidence.merge("completion_ref" => reference),
                  ),
                )
              end
            end
          end

          def complete_admitted_social_signup!(commit, provider, binding)
            normalized_provider = SocialIdentifiable.normalize_provider(provider)
            ceremony = binding.admitted_auth_ceremony_session
            if binding.parent_kind == :authorization_transaction
              return handoff_social_signup_oidc!(commit, normalized_provider, binding, ceremony)
            end

            complete_social_signup_local_login!(commit, normalized_provider, binding, ceremony)
          end

          def handoff_social_signup_oidc!(commit, normalized_provider, binding, ceremony)
            issuance = BaseAuthAdmissionCoordinator.register_result_and_issue!(
              surface: "app",
              login_challenge: binding.authorization_transaction.login_challenge,
              actor: commit.user,
              session_ref: nil,
              auth_method: AuthenticationBase::ESTABLISHED_AUTHENTICATION_METHOD_AMR_MAP.fetch(normalized_provider).first,
              acr: nil,
              authentication_event_at: ceremony.authentication_event_at,
            )
            record_social_signup_completion!(commit, issuance.reference)
            ceremony.complete! unless ceremony.completed?
            redirect_to(
              base_app_oauth_authorization_path(
                result_ref: issuance.reference, transaction_ref: issuance.transaction.transaction_id, ri: params[:ri],
              ), status: :see_other,
            )
          end

          def complete_social_signup_local_login!(commit, normalized_provider, binding, ceremony)
            flow = binding.sign_in_flow
            bind_social_signup_local_parent!(commit.user, flow, normalized_provider, ceremony)
            browser_nonce = base_admission_browser_nonce
            result = log_in(
              commit.user, establishment: :root_login, sign_in_flow: flow,
                           established_authentication_method: normalized_provider,
                           authentication_event_at: ceremony.authentication_event_at,
                           audit_context: { auth_method: "social", provider: normalized_provider },
            )
            sign_in_result = sign_in_result_from_session_result(result, actor: commit.user)
            unless sign_in_result.success? || sign_in_result.session_limit_pending?
              return handle_social_login_failure!(sign_in_result)
            end

            session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] = browser_nonce
            record_social_signup_completion!(commit, flow.public_id)
            ceremony.complete! unless ceremony.completed?
            destination =
              sign_in_result.session_limit_pending? ? social_session_limitation_path :
                           base_app_dashboard_path(ri: params[:ri])
            redirect_to(destination, status: :see_other)
          end

          def bind_social_signup_local_parent!(user, flow, provider, ceremony)
            user.with_lock do
              AppTicketRecord.connected_to(role: :writing) do
                flow.with_lock do
                  if flow.principal_id == user.id &&
                      (flow.sign_in_primary_pending? || flow.sign_in_session_issuance_pending?) &&
                      flow.authentication_method == provider &&
                      flow.authentication_event_at == ceremony.authentication_event_at
                    return
                  end

                  unless flow.sign_in_primary_pending? && flow.principal_id.nil? &&
                      !flow.expired?(flow.class.database_now)
                    raise IdentitySocialCeremonyContract::Error, "social sign-in parent is unavailable"
                  end

                  flow.update!(principal_id: user.id)
                  flow.record_local_authentication_evidence!(
                    method: provider, authenticated_at: ceremony.authentication_event_at,
                  )
                end
              end
            end
          end

          def base_social_login_redirect_to(sign_in_result)
            return social_session_limitation_path if sign_in_result.session_limit_pending?

            sign_in_result.redirect_to
          end

          # The pending sign-in flow is held by the flow locator in this Base host's
          # Rails session, so the limitation page is a same-host path; the URL itself
          # carries no grant.
          def social_session_limitation_path
            base_app_sign_in_limitation_path(ri: params[:ri])
          end

          def handle_social_login_failure!(sign_in_result)
            if sign_in_result.status == :mfa_required
              return redirect_to(sign_in_result.redirect_to)
            end

            render_social_completion_failure(
              message: sign_in_result.message.presence || I18n.t("sign.app.social.sessions.create.failure"),
              status: sign_in_result.response_status,
            )
          end

          def render_social_completion_failure(
            message: I18n.t("sign.app.social.sessions.create.failure"),
            status: :unprocessable_content
          )
            render plain: message, status: status
          end
        end
      end
    end
  end
end
