# typed: false
# frozen_string_literal: true

require "base64"

module Auth
  module App
    module Sign
      module In
        module Challenge
          class PasskeysController < ::Auth::App::ApplicationController
            include ::AuthenticationModeSwitchGuard
            include ::SurfaceInertiaPage

            include ::PasskeyCeremonyContext

            include SessionLimitGate

            include ::CloudflareTurnstile

            AUTHENTICATION_MODE = :guest

            prepend_before_action :require_sign_in_ceremony_admission!
            ensure_fqdn_gate_first!
            prepend_before_action :apply_default_no_store

            rate_limit(
              to: 5,
              within: 1.minute,
              by: -> { request.remote_ip },
              scope: "auth_app_sign_in",
              name: "mfa_passkey_create_ip_burst",
              store: rate_limit_store,
              only: :create,
              with: -> {
                render_rate_limited(retry_after: 60)
              },
            )
            rate_limit(
              to: 20,
              within: 15.minutes,
              by: -> { request.remote_ip },
              scope: "auth_app_sign_in",
              name: "mfa_passkey_create_ip_sustained",
              store: rate_limit_store,
              only: :create,
              with: -> {
                render_rate_limited(retry_after: 900)
              },
            )

            before_action :ensure_pending_mfa!

            def new
              @mfa_user = pending_mfa_user
              passkeys = active_passkeys_for(@mfa_user)

              if passkeys.empty?
                redirect_to(
                  auth_app_sign_in_challenge_path,
                  status: :see_other,
                )
                return
              end

              @passkey_challenge_id, @passkey_request_options =
                issue_passkey_authentication_challenge(
                  allow_credentials: passkeys, actor: @mfa_user,
                  uv_purpose: :mfa_challenge,
                )

              render inertia: true, props: challenge_passkey_props
            rescue Webauthn::RelyingPartyConfigResolver::MissingConfigurationError => e
              Rails.logger.error(JitLogEvent.format("webauthn.origin_validation_failed", error: e.message))
              redirect_to(
                auth_app_sign_in_challenge_path,
                status: :see_other,
              )
            end

            def create
              unless cloudflare_turnstile_stealth_validation["success"]
                redirect_to(
                  new_auth_app_sign_in_challenge_passkey_path,
                  status: :see_other,
                )
                return
              end

              challenge = consume_passkey_challenge!(
                passkey_params[:challenge_id], purpose: :authentication, actor: pending_mfa_user,
              )
              verify_passkey!(challenge)
            rescue Webauthn::ChallengeStore::ChallengeError,
                   Webauthn::AssertionVerifier::VerificationError, WebAuthn::Error
              redirect_to(
                auth_app_sign_in_challenge_path,
                status: :see_other,
              )
            end

            private

            def challenge_passkey_props
              scope = "sign.app.in.mfa.passkey"

              {
                title: page_t("#{scope}.title"),
                description: page_t("#{scope}.description"),
                form: {
                  action: auth_app_sign_in_challenge_passkey_path,
                  # The assertion is posted as a native document POST, so the form carries the same
                  # masked per-session authenticity token the ERB form embedded.
                  authenticity_token: form_authenticity_token,
                  param_scope: "mfa_passkey_form",
                  challenge_id: @passkey_challenge_id.to_s,
                  # The challenge options are the payload `navigator.credentials.get` needs, and the
                  # ERB already embedded exactly this object in the page.
                  request_options: @passkey_request_options,
                  submit_label: page_t("#{scope}.authenticate"),
                },
                back_link: { label: page_t("#{scope}.back"), href: auth_app_sign_in_challenge_path },
                cancel: { label: t("actions.cancel"), action: auth_app_sign_in_challenge_path, method: "delete" },
              }
            end

            def ensure_pending_mfa!
              return unless !pending_mfa_valid? || pending_mfa_user.nil?

              clear_pending_mfa!
              redirect_to(
                auth_app_sign_in_path,
                status: :see_other,
              )
            end

            def active_passkeys_for(user)
              ClientPasskey.connection_class_for_self.connected_to(role: :writing) do
                user.client_passkeys.where(status_id: ClientPasskeyStatus::ACTIVE)
                  .where("discard_at > ?", ClientPasskey.database_now).to_a
              end
            end

            def passkey_params
              params.fetch(:mfa_passkey_form, {}).permit(:challenge_id, :credential_json)
            end

            def mfa_credential_payload
              payload = JSON.parse(passkey_params[:credential_json].to_s)
              identifier = payload["id"] if payload.is_a?(Hash)
              unless identifier.is_a?(String) && identifier.present? && identifier.exclude?("\0")
                raise Webauthn::AssertionVerifier::VerificationError, "invalid WebAuthn credential payload"
              end

              payload
            end

            def verify_passkey!(challenge)
              credential_payload = mfa_credential_payload
              ClientPasskey.connection_class_for_self.connected_to(role: :writing) do
                user = pending_mfa_user
                return redirect_to(auth_app_sign_in_challenge_path, status: :see_other) unless user

                user.with_lock do
                  passkey = user.client_passkeys.lock.find_by(webauthn_id: credential_payload["id"])
                  unless passkey && user.login_allowed? && passkey.status_id == ClientPasskeyStatus::ACTIVE &&
                      ClientPasskey.where(id: passkey.id).exists?(["discard_at > ?", ClientPasskey.database_now])
                    SignRiskEmitter.emit(
                      "auth_failed", user_id: user.id, ip: request.remote_ip,
                                     reason: "mfa_passkey_mismatch",
                    )
                    return redirect_to(auth_app_sign_in_challenge_path, status: :see_other)
                  end

                  context = Webauthn::AssertionVerifier.verify!(
                    credential_params: credential_payload,
                    challenge: challenge,
                    config: webauthn_relying_party_config,
                    public_key: passkey.public_key,
                    sign_count: passkey.sign_count,
                    purpose: :mfa_challenge,
                  )
                  passkey.update!(
                    sign_count: context.sign_count, last_used_at: context.verified_at,
                    uv_verified_at: context.verified_at,
                  )

                  complete_mfa_login!(user)
                end
              end
            rescue JSON::ParserError
              redirect_to(
                auth_app_sign_in_challenge_path,
                status: :see_other,
              )
            end

            def complete_mfa_login!(user)
              result = finalize_mfa_login!(user)
              case result[:status]
              when :session_limit_hard_reject
                render_session_limit_hard_reject(message: result[:message], http_status: result[:http_status])
              when :session_limit_pending
                redirect_to(result[:redirect_path])
              when :success, :authentication_evidence_recorded
                redirect_to_sign_in_sequence!(
                  pt: result[:redirect_path],
                )
              when :invalid_request
                if local_authentication_ceremony?
                  clear_auth_ceremony_context!
                  redirect_to(
                    base_app_sign_show_url(
                      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"), protocol: "https",
                      ri: RequestContextContract.normalize_region(params[:ri]),
                    ),
                    status: :see_other, allow_other_host: true,
                  )
                else
                  redirect_to(auth_app_sign_in_path(ri: params[:ri]), status: :see_other)
                end
              else
                redirect_to(
                  auth_app_sign_in_path,
                  status: :see_other,
                )
              end
            end
          end
        end
      end
    end
  end
end
