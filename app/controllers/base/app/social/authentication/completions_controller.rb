# typed: false
# frozen_string_literal: true

module Base
  module App
    module Social
      module Authentication
        # POST /social/authentication/completion
        # Consumes the signed social ceremony result posted back from the Auth
        # host and establishes the app session (or enters the sign-up cycle).
        class CompletionsController < ::Base::App::ApplicationController
          include SocialCeremonyParams

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          # The browser posts the signed ceremony result here from the Auth host
          # (auth/shared/social_completion.html.erb), so the Origin is the Auth
          # origin, not this Base origin. Base::App::ApplicationController trusts
          # its own origin only, which rejects that handoff before the action
          # runs and strands the ceremony on the auto-posting page. Trust the Auth
          # origin locally, as Base::App::Oidc::LogoutsController does for its own
          # cross-surface POST. The payload itself is still only accepted through
          # IdentitySocialCeremonyFinalCommitter's signature and one-shot checks.
          SOCIAL_COMPLETION_TRUSTED_ORIGINS = JitHostOriginEnv.trusted_origins(
            ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
          ).freeze

          protect_from_forgery using: :header_or_legacy_token,
                               trusted_origins: SOCIAL_COMPLETION_TRUSTED_ORIGINS,
                               with: :exception

          def create
            provider = social_provider_param
            result_token = params.require(:social_ceremony_result)
            # The payload here is UNVERIFIED/untrusted. We read `operation` only to
            # fail-safe REJECT link completions on this login-only base path. The
            # actual trust decision happens in IdentitySocialCeremonyFinalCommitter
            # below, which re-derives `operation` from the cryptographically
            # verified result, so tampering this value cannot grant anything.
            payload = IdentitySocialCeremonyContract.decode_untrusted_routing_payload(result_token)
            return reject_social_link_completion!(provider) if payload["operation"].to_s == "link"

            commit = IdentitySocialCeremonyFinalCommitter.call!(
              result_token: result_token,
              actor: nil,
              session_ref: social_result_session_ref(result_token),
              surface: "app",
              ip_address: request.remote_ip,
              user_agent: request.user_agent,
            )
            raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless commit.user

            return complete_social_signup!(commit, provider) if commit.result["operation"].to_s != "signup" &&
              social_sign_up_required?(commit)

            complete_social_login!(commit, provider)
          rescue IdentitySocialCeremonyContract::Error, ActionController::ParameterMissing, ActiveRecord::RecordNotFound
            render_social_completion_failure
          rescue SocialAuth::BaseError => e
            render_social_completion_failure(message: e.message)
          end

          private

          # An access proxy in front of this host redirects the handoff POST through its
          # own origin before it reaches Rails. That cross-origin redirect sets the
          # browser's tainted origin flag, so the request arrives with `Origin: null`
          # instead of the Auth origin and the trusted-origin list above never matches.
          #
          # Accept the opaque origin only when the browser also reports
          # Sec-Fetch-Site: same-site, which a cross-site attacker page cannot claim:
          # its submission arrives as "cross-site". Trust still rests on the signed,
          # one-shot ceremony result verified in the action.
          #
          # Remove this once no proxy redirects the POST: the browser then sends the
          # real Auth origin, which SOCIAL_COMPLETION_TRUSTED_ORIGINS already allows.
          def valid_request_origin?
            return true if opaque_same_site_ceremony_post?

            super
          end

          def opaque_same_site_ceremony_post?
            request.origin.to_s == "null" && sec_fetch_site_value == "same-site"
          end

          def reject_social_link_completion!(provider)
            redirect_to(
              sign_social_settings_url_for(provider),
              allow_other_host: cross_host_redirect_allowed?,
              status: :see_other,
            )
          end

          def sign_social_settings_url_for(provider)
            if SocialIdentifiable.normalize_provider(provider) == "apple"
              auth_app_settings_apple_url(
                ri: params[:ri],
                host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
              )
            else
              auth_app_settings_google_url(
                ri: params[:ri],
                host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
              )
            end
          end

          def complete_social_login!(commit, provider)
            # Social login reuses the same graph-provisioning boundary as
            # sign-up finalization. The final durable state is still written
            # through the app-side selector bootstrap after provider proof.
            IdentityGraphProvisioner.call!(surface: :app, principal: commit.user)
            normalized_provider = SocialIdentifiable.normalize_provider(provider)
            result = AuthenticationSessionCommitter.call(
              controller: self,
              resource: commit.user,
              pt: commit.pt,
              ri: params[:ri],
              auth_method: "social",
              authentication_event_at: authentication_event_at_from_social_result(commit.result),
              audit_context: { auth_method: "social", provider: normalized_provider },
              # "social" cannot distinguish google from apple; the provider is
              # known here (adr/unified-enforcement.md, Session attribution).
              established_authentication_method: normalized_provider,
            )
            sign_in_result = sign_in_result_from_session_result(result, actor: commit.user)

            if sign_in_result.status == :success || sign_in_result.status == :session_limit_pending
              signup_flow = commit.result["operation"].to_s == "signup"
              complete_base_social_signup_flow!(commit, sign_in_result) if signup_flow
              redirect_url = base_social_login_redirect_to(sign_in_result)
              return redirect_to(
                redirect_url,
                allow_other_host: base_social_login_redirect_allows_other_host?(redirect_url),
              )
            end

            handle_social_login_failure!(sign_in_result)
          end

          def authentication_event_at_from_social_result(result)
            raw = result.is_a?(Hash) ? result["auth_time"] : nil
            parse_authentication_event_at(raw)
          end

          def base_social_login_redirect_to(sign_in_result)
            return social_session_limitation_url(sign_in_result.actor) if sign_in_result.session_limit_pending?

            sign_in_result.redirect_to
          end

          def base_social_login_redirect_allows_other_host?(redirect_url)
            social_session_limitation_url?(redirect_url) || after_login_allows_other_host?
          end

          def social_session_limitation_url?(redirect_url)
            uri = URI.parse(redirect_url.to_s)
            uri.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
              uri.path == "/sign/in/limitation"
          rescue URI::InvalidURIError
            false
          end

          def social_session_limitation_url(actor)
            token = Rails.application.message_verifier(:social_session_limit_limitation).generate(
              {
                "actor_ref" => actor.public_id,
                "session_ref" => current_session&.public_id,
                "expires_at" => 15.minutes.from_now.iso8601,
              },
            )
            base_app_sign_in_limitation_url(
              social_resolution: token,
              ri: params[:ri],
              host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
            )
          end

          def complete_social_signup!(commit, provider)
            cycle = create_social_sign_up_flow!(commit)
            bind_social_sign_up_flow!(cycle, commit)
            normalized_provider = SocialIdentifiable.normalize_provider(provider)
            redirect_to(
              public_send(
                :"auth_app_sign_up_guard_#{normalized_provider}_url",
                ri: params[:ri],
                pt: signed_pt_token(commit.pt),
                host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
              ),
              allow_other_host: cross_host_redirect_allowed?,
            )
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

          def social_sign_up_required?(commit)
            !commit.existing_account || commit.user&.birthdate.blank?
          end

          def complete_base_social_signup_flow!(commit, sign_in_result)
            # Unknown social identities enter the sign-up cycle first, then
            # reuse the shared finalize/handoff/complete path once the
            # callback has been bound to the pending ticket.
            flow_id = commit.result["actor_ref"].to_s
            return if flow_id.blank?

            AppTicketRecord.connected_to(role: :writing) do
              cycle = ClientSignUpFlow.find_by!(public_id: flow_id)
              cycle.with_cycle_lock do
                cycle.reload
                cycle.update!(
                  principal_id: commit.user.id,
                  pending_contact_type: "social_identity",
                  pending_contact_id: commit.identity.id,
                  social_provider: SocialIdentifiable.normalize_provider(commit.identity.provider),
                )
                finalize = SignUpStateMachine.call(
                  ticket: cycle,
                  event: :finalize,
                  actor_context: Actor.authn,
                  payload: { finalization_result: :accepted },
                )
                raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless finalize.success?

                handoff = SignUpStateMachine.call(
                  ticket: cycle,
                  event: :handoff_to_sign_in,
                  actor_context: Actor.authn,
                  payload: {
                    sign_in_handoff_status: :accepted,
                    sign_in_handoff: sign_in_result.status,
                  },
                )
                raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless handoff.success?

                complete = SignUpStateMachine.call(
                  ticket: cycle,
                  event: :complete,
                  actor_context: Actor.authn,
                )
                raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless complete.success?
              end
            end
          end

          def create_social_sign_up_flow!(commit)
            # The callback only creates the pending sign-up ticket here; the
            # durable identity graph is still created later by the shared
            # sign-up finalize boundary.
            AppTicketRecord.connected_to(role: :writing) do
              ClientSignUpFlowStatus.ensure_defaults!
              ClientSignUpFlow.create!(
                principal_id: nil,
                status_id: ClientSignUpFlowStatus::SOCIAL_CALLBACK_PENDING,
                step: "social_callback",
                nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
                issued_at: Time.current,
                expires_at: ClientSignUpFlow.default_ttl.from_now,
                entry_method: SocialIdentifiable.normalize_provider(commit.identity.provider),
                social_provider: SocialIdentifiable.normalize_provider(commit.identity.provider),
                return_to: safe_social_return_to(commit.pt),
              )
            end
          end

          def bind_social_sign_up_flow!(cycle, commit)
            identity = commit.identity
            raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless identity&.persisted?
            raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless identity.user_id ==
              commit.user.id

            AppTicketRecord.connected_to(role: :writing) do
              cycle.update!(
                principal_id: commit.user.id,
                pending_contact_type: "social_identity",
                pending_contact_id: identity.id,
                social_provider: SocialIdentifiable.normalize_provider(identity.provider),
              )
              result = SignUpStateMachine.call(
                ticket: cycle,
                event: :complete_social_callback,
                actor_context: Actor.authn,
              )
              raise SocialAuth::ProviderError.new("errors.social_auth.provider_error") unless result.status == :advanced
            end
            SignUpCycleLocator.new(session, surface: :app, cycle_class: ClientSignUpFlow).issue!(cycle)
            session[:auth_app_up_sequence_id] = cycle.public_id
          end

          # Extracts `session_ref` from the UNVERIFIED payload purely so it can be
          # passed to IdentitySocialCeremonyFinalCommitter. The committer compares
          # it against the verified result["session_ref"] (mismatch => rejection),
          # so this untrusted value is a routing input, never a trust anchor.
          def social_result_session_ref(result_token)
            IdentitySocialCeremonyContract.decode_untrusted_routing_payload(result_token).fetch("session_ref")
          end
        end
      end
    end
  end
end
