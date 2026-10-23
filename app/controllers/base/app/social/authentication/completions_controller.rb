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
            ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
            # A committed signup is never completed again here: that would issue a root login to
            # whichever browser presents the pre-login browser binding.
            raise IdentitySocialCeremonyContract::Error, "social completion is not finished" unless ceremony.completed?

            flow = ClientSignUpFlow.find_by!(public_id: commit.result["actor_ref"])
            reference = flow.completed_requirements.fetch("social_signup").fetch("completion_ref")
            raise IdentitySocialCeremonyContract::Error, "social completion parent is invalid" unless
              binding.parent_kind == :authorization_transaction
            raise IdentitySocialCeremonyContract::Error, "social completion reference is invalid" unless
              reference.is_a?(String) && reference.match?(AuthAdmissionBinding::REFERENCE_PATTERN)

            redirect_to(
              base_app_oauth_authorization_path(
                result_ref: reference,
                transaction_ref: ClientOidcAuthorizationTransaction.find(
                  binding.authorization_transaction_id,
                ).transaction_id,
                ri: params[:ri],
              ),
              status: :see_other,
            )
          end

          def record_social_signup_completion!(commit, reference)
            OpBaseAppRecord.connected_to(role: :writing) do
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
            ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
            # Only an OIDC authorization parent continues a social sign-up; Base issues the root login
            # when that authorization resumes.
            unless binding.parent_kind == :authorization_transaction
              raise IdentitySocialCeremonyContract::Error, "social sign-up parent is invalid"
            end

            handoff_social_signup_oidc!(commit, normalized_provider, binding, ceremony)
          end

          def handoff_social_signup_oidc!(commit, normalized_provider, binding, ceremony)
            issuance = BaseAuthAdmissionCoordinator.register_result_and_issue!(
              surface: "app",
              login_challenge: ClientOidcAuthorizationTransaction.find(
                binding.authorization_transaction_id,
              ).login_challenge,
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
