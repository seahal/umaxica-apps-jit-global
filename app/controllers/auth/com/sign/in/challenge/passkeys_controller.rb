# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module In
        module Challenge
          class PasskeysController < ::Auth::Com::ApplicationController
            include ::AuthenticationModeSwitchGuard
            include ::PasskeyCeremonyContext
            include ::SurfaceInertiaPage

            include SessionLimitGate

            include ::CloudflareTurnstile

            AUTHENTICATION_MODE = :guest

            rate_limit(
              to: 5,
              within: 1.minute,
              by: -> { request.remote_ip },
              scope: "auth_com_sign_in",
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
              scope: "auth_com_sign_in",
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
                  auth_com_sign_in_challenge_path(ri: current_region_identifier),
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
              Rails.logger.error(JitLogEvent.format("webauthn.origin_validation_failed", message: e.message))
              redirect_to(
                auth_com_sign_in_challenge_path(ri: current_region_identifier),
                status: :see_other,
              )
            end

            def create
              unless cloudflare_turnstile_stealth_validation["success"]
                redirect_to(
                  new_auth_com_sign_in_challenge_passkey_path(ri: current_region_identifier),
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
                auth_com_sign_in_challenge_path(ri: current_region_identifier),
                status: :see_other,
              )
            end

            private

            def challenge_passkey_props
              ri = current_region_identifier

              {
                title: t("sign.app.in.mfa.passkey.title"),
                description: t("sign.app.in.mfa.passkey.description"),
                form: {
                  action: auth_com_sign_in_challenge_passkey_path(ri: ri),
                  # The assertion is posted as a native document POST, so the form carries the same
                  # masked per-session authenticity token.
                  authenticity_token: form_authenticity_token,
                  param_scope: "mfa_passkey_form",
                  challenge_id: @passkey_challenge_id.to_s,
                  # The challenge options are the payload `navigator.credentials.get` needs.
                  request_options: @passkey_request_options,
                  submit_label: t("sign.app.in.mfa.passkey.authenticate"),
                },
                back_link: { label: t("sign.app.in.mfa.passkey.back"), href: auth_com_sign_in_challenge_path(ri: ri) },
              }
            end

            def ensure_pending_mfa!
              return unless !pending_mfa_valid? || pending_mfa_user.nil?

              clear_pending_mfa!
              redirect_to(
                auth_com_sign_in_path(ri: current_region_identifier),
                status: :see_other,
              )
            end

            def active_passkeys_for(visitor)
              visitor.visitor_passkeys.where(status_id: VisitorPasskeyStatus::ACTIVE)
            end

            def passkey_params
              params.fetch(:mfa_passkey_form, {}).permit(:challenge_id, :credential_json)
            end

            def verify_passkey!(challenge)
              credential_payload = JSON.parse(passkey_params[:credential_json].to_s)
              passkey = VisitorPasskey.find_by(webauthn_id: credential_payload["id"])

              visitor = pending_mfa_user
              unless passkey && visitor && passkey.visitor_id == visitor.id
                SignRiskEmitter.emit(
                  "auth_failed",
                  visitor_id: visitor&.id,
                  ip: request.remote_ip,
                  reason: "mfa_passkey_mismatch",
                )
                redirect_to(
                  auth_com_sign_in_challenge_path(ri: current_region_identifier),
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

              complete_mfa_login!(visitor)
            rescue JSON::ParserError
              redirect_to(
                auth_com_sign_in_challenge_path(ri: current_region_identifier),
                status: :see_other,
              )
            end

            def complete_mfa_login!(visitor)
              result = finalize_mfa_login!(visitor)
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
                  auth_com_sign_in_path(ri: current_region_identifier),
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
