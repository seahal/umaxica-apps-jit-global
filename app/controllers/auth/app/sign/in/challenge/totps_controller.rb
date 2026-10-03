# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module In
        module Challenge
          class TotpsController < ::Auth::App::ApplicationController
            include ::AuthenticationModeSwitchGuard
            include ::SurfaceInertiaPage

            include ::TurnstilePageProps

            include SessionLimitGate

            include ::CloudflareTurnstile

            AUTHENTICATION_MODE = :guest

            rate_limit(
              to: 5,
              within: 1.minute,
              by: -> { request.remote_ip },
              scope: "auth_app_sign_in",
              name: "mfa_totp_create_ip_burst",
              store: rate_limit_store,
              only: :create,
              with: -> { render_rate_limited(retry_after: 60) },
            )
            rate_limit(
              to: 20,
              within: 15.minutes,
              by: -> { request.remote_ip },
              scope: "auth_app_sign_in",
              name: "mfa_totp_create_ip_sustained",
              store: rate_limit_store,
              only: :create,
              with: -> {
                render_rate_limited(retry_after: 900)
              },
            )
            # Per-account limit. The two rules above are keyed by source IP, so a
            # distributed attacker gets unbounded guesses against one account's
            # 6-digit TOTP. This rule is an auxiliary throttle only: it lives in the
            # rate-limit store, which fails open when Valkey is unreachable. The
            # authoritative per-account lockout is the PostgreSQL state that
            # TotpWindowConsumer maintains on ClientTotpCredential, the TOTP
            # equivalent of the email/SMS OTP lock (OtpLockable).
            rate_limit(
              to: 10,
              within: 15.minutes,
              by: -> {
                actor_id = pending_mfa&.dig(:user_id)
                actor_id.present? ? "client:#{actor_id}" : "unbound:#{request.remote_ip}"
              },
              scope: "auth_app_sign_in",
              name: "mfa_totp_create_account",
              store: rate_limit_store,
              only: :create,
              with: -> {
                render_rate_limited(retry_after: 900)
              },
            )

            class TotpChallengeForm
              include ActiveModel::Model

              attr_accessor :token, :credential_public_id

              validates :token, presence: true, length: { is: 6 }

              def self.model_name
                ActiveModel::Name.new(self, nil, "totp_challenge_form")
              end
            end

            before_action :ensure_pending_mfa!

            def new
              @totp_form = TotpChallengeForm.new
              render_totp_new
            end

            def create
              @totp_form = TotpChallengeForm.new(totp_params)
              unless @totp_form.valid?
                return render_totp_new(status: :unprocessable_content)
              end

              unless cloudflare_turnstile_stealth_validation["success"]
                @totp_form.errors.add(
                  :base, t("session_limit.turnstile_failed"),
                )
                return render_totp_new(status: :unprocessable_content)
              end

              user = pending_mfa_user
              result = consume_totp_for(user, @totp_form.token, @totp_form.credential_public_id)

              if result.accepted?
                handle_totp_success(user)
              else
                reason = result.replay? ? "totp_replay" : "totp_mismatch"
                SignRiskEmitter.emit("auth_failed", user_id: user&.id, ip: request.remote_ip, reason: reason)
                message =
                  result.credential_required? ? t("messages.totp_credential_required") :
                                   t("sign.app.in.mfa.verification_failed")
                @totp_form.errors.add(:base, message)
                render_totp_new(status: :unprocessable_content)
              end
            end

            private

            # Named rather than derived: `create` re-renders this same page on every failure branch.
            def render_totp_new(status: :ok)
              render inertia: "auth/app/sign/in/challenge/totps/new", props: totp_new_props, status: status
            end

            def totp_new_props
              scope = "sign.app.in.mfa.totp"

              {
                title: page_t("#{scope}.title"),
                description: page_t("#{scope}.description"),
                form: {
                  action: auth_app_sign_in_challenge_totp_path,
                  method: "post",
                  token_field: {
                    scope: "totp_challenge_form",
                    field: "token",
                    name: "totp_challenge_form[token]",
                    label: page_t("#{scope}.token_label"),
                    placeholder: page_t("#{scope}.token_placeholder"),
                    max_length: 6,
                    inputmode: "numeric",
                    help: page_t("#{scope}.help"),
                  },
                  credential_selector: totp_credential_selector_props(pending_mfa_user),
                  submit_label: page_t("#{scope}.submit"),
                },
                error_heading: t("errors.messages.validation_failed"),
                form_errors: @totp_form.errors.full_messages,
                turnstile: turnstile_stealth_props,
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

            def consume_totp_for(user, token, credential_public_id)
              TotpWindowConsumer.call(
                credentials: user.client_totp_credentials
                  .where(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
                  .order(created_at: :desc),
                token: token,
                credential_public_id: credential_public_id,
              )
            end

            def totp_credential_selector_props(user)
              credentials = user.client_totp_credentials
                .where(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
                .order(created_at: :asc)
                .to_a
              return unless credentials.length > 1

              {
                name: "totp_challenge_form[credential_public_id]",
                field: "credential_public_id",
                scope: "totp_challenge_form",
                label: t("messages.totp_credential_label"),
                options: credentials.each_with_index.map do |credential, index|
                  {
                    value: credential.public_id,
                    label: credential.title.presence || t("messages.totp_credential_default_label", count: index + 1),
                  }
                end,
              }
            end

            def handle_totp_success(user)
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
              else
                redirect_to(
                  auth_app_sign_in_path,
                  status: :see_other,
                )
              end
            end

            def totp_params
              params.fetch(:totp_challenge_form, {}).permit(:token, :credential_public_id)
            end
          end
        end
      end
    end
  end
end
