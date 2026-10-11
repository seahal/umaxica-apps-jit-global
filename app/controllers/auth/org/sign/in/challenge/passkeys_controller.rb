# typed: false
# frozen_string_literal: true

require "base64"

module Auth
  module Org
    module Sign
      module In
        module Challenge
          class PasskeysController < ::Auth::Org::ApplicationController
            include ::AuthenticationModeSwitchGuard
            include ::PasskeyCeremonyContext

            include SessionLimitGate

            include ::CloudflareTurnstile

            include ::SurfaceInertiaPage

            AUTHENTICATION_MODE = :guest

            rate_limit(
              to: 5,
              within: 1.minute,
              by: -> { request.remote_ip },
              scope: "auth_org_sign_in",
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
              scope: "auth_org_sign_in",
              name: "mfa_passkey_create_ip_sustained",
              store: rate_limit_store,
              only: :create,
              with: -> {
                render_rate_limited(retry_after: 900)
              },
            )

            before_action :ensure_pending_mfa!

            def new
              @mfa_staff = pending_mfa_user
              passkeys = active_passkeys_for(@mfa_staff)

              if passkeys.empty?
                redirect_to(
                  auth_org_sign_in_challenge_path,
                  status: :see_other,
                )
                return
              end

              @passkey_challenge_id, @passkey_request_options =
                issue_passkey_authentication_challenge(
                  allow_credentials: passkeys, actor: @mfa_staff,
                  uv_purpose: :mfa_challenge,
                )
              render inertia: true, props: mfa_passkey_props
            rescue Webauthn::RelyingPartyConfigResolver::MissingConfigurationError => e
              Rails.logger.error(JitLogEvent.format("webauthn.origin_validation_failed", message: e.message))
              redirect_to(
                auth_org_sign_in_challenge_path,
                status: :see_other,
              )
            end

            def create
              unless cloudflare_turnstile_stealth_validation["success"]
                redirect_to(
                  new_auth_org_sign_in_challenge_passkey_path,
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
                auth_org_sign_in_challenge_path,
                status: :see_other,
              )
            end

            private

            def mfa_passkey_props
              {
                title: t("sign.org.in.mfa.passkey.title"),
                description: t("sign.org.in.mfa.passkey.description"),
                form: {
                  action: auth_org_sign_in_challenge_passkey_path,
                  param_scope: "mfa_passkey_form",
                  challenge_id: @passkey_challenge_id.to_s,
                  request_options: @passkey_request_options.as_json,
                  submit_label: t("sign.org.in.mfa.passkey.authenticate"),
                },
                back_link: {
                  label: t("sign.org.in.mfa.passkey.back"),
                  href: auth_org_sign_in_challenge_path,
                },
              }
            end

            def ensure_pending_mfa!
              return unless !pending_mfa_valid? || pending_mfa_user.nil?

              clear_pending_mfa!
              redirect_to(
                auth_org_sign_in_path,
                status: :see_other,
              )
            end

            def active_passkeys_for(staff)
              staff.staff_passkeys.where(status_id: OperatorPasskeyStatus::ACTIVE)
            end

            def passkey_params
              params.fetch(:mfa_passkey_form, {}).permit(:challenge_id, :credential_json)
            end

            def verify_passkey!(challenge)
              credential_payload = JSON.parse(passkey_params[:credential_json].to_s)
              passkey = OperatorPasskey.find_by(webauthn_id: credential_payload["id"])

              staff = pending_mfa_user
              unless passkey && staff && passkey.staff_id == staff.id
                SignRiskEmitter.emit(
                  "auth_failed", staff_id: staff&.id, ip: request.remote_ip,
                                 reason: "mfa_passkey_mismatch",
                )
                redirect_to(
                  auth_org_sign_in_challenge_path,
                  status: :see_other,
                )
                return
              end

              context = Webauthn::AssertionVerifier.verify!(
                credential_params: credential_payload,
                challenge: challenge,
                config: webauthn_relying_party_config,
                public_key: passkey.public_key,
                sign_count: passkey.sign_count,
                purpose: :mfa_challenge,
              )
              passkey.update!(sign_count: context.sign_count, last_used_at: Time.current)

              complete_mfa_login!(staff)
            rescue JSON::ParserError
              redirect_to(
                auth_org_sign_in_challenge_path,
                status: :see_other,
              )
            end

            def complete_mfa_login!(staff)
              result = finalize_mfa_login!(staff)
              case result[:status]
              when :session_limit_hard_reject
                render_session_limit_hard_reject(message: result[:message], http_status: result[:http_status])
              when :restricted
                redirect_to(result[:redirect_path])
              when :success
                redirect_to_sign_in_sequence!(
                  pt: result[:redirect_path],
                )
              else
                redirect_to(
                  auth_org_sign_in_path,
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
