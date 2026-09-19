# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module In
        class SecretsController < ::Auth::App::ApplicationController
          include ::AuthenticationModeSwitchGuard
          include ::SurfaceInertiaPage

          include ::TurnstilePageProps

          include ::CloudflareTurnstile

          include EmailValidation

          include IdentifierDetection

          include CommonRedirect

          include MinimumResponseBudget

          include SessionLimitGate

          AUTHENTICATION_MODE = :guest

          SecretVerificationResult = Struct.new(:secret_credential, :reason, :details, keyword_init: true)

          MFA_USER_SESSION_KEY = :mfa_user_id

          rate_limit(
            to: 5,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "auth_app_sign_in",
            name: "secret_credential_create_ip_burst",
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
            name: "secret_credential_create_ip_sustained",
            store: rate_limit_store,
            only: :create,
            with: -> {
              render_rate_limited(retry_after: 900)
            },
          )
          # Per-account limit for the second-factor path. The two rules above are
          # keyed by source IP, so a distributed attacker otherwise gets unbounded
          # guesses against one account's secret credential once the primary factor
          # has been established.
          rate_limit(
            to: 10,
            within: 15.minutes,
            by: -> {
              actor_id = pending_mfa&.dig(:user_id)
              actor_id.present? ? "client:#{actor_id}" : "unbound:#{request.remote_ip}"
            },
            scope: "auth_app_sign_in",
            name: "secret_credential_create_account",
            store: rate_limit_store,
            only: :create,
            with: -> {
              render_rate_limited(retry_after: 900)
            },
          )
          rate_limit(
            to: 10,
            within: 15.minutes,
            by: -> {
              AuthenticationRateLimitKey.for(
                surface: :app,
                identifier: request.request_parameters.dig("secret_credential_login_form", "identifier"),
              )
            },
            scope: "auth_app_sign_in",
            name: "secret_credential_create_identifier",
            store: rate_limit_store,
            only: :create,
            unless: -> { pending_mfa_valid? },
            with: -> {
              render_rate_limited(retry_after: 900)
            },
          )
          before_action :start_minimum_response_budget
          after_action :enforce_minimum_response_budget

          class SecretLoginForm
            include ActiveModel::Model

            attr_accessor :identifier, :secret_credential_value, :turnstile_response

            validates :secret_credential_value, presence: true
            validate :identifier_present_and_valid

            def self.model_name
              ActiveModel::Name.new(self, nil, "secret_credential_login_form")
            end

            private

            def identifier_present_and_valid
              value = identifier.to_s.strip
              return errors.add(:base, :blank) if value.blank?
              return if value.include?("@") || value.include?("+")

              errors.add(:identifier, :invalid)
            end
          end

          class MfaSecretForm
            include ActiveModel::Model

            attr_accessor :secret_credential_value, :turnstile_response

            validates :secret_credential_value, presence: true

            def self.model_name
              ActiveModel::Name.new(self, nil, "mfa_secret_credential_form")
            end
          end

          def new
            if mfa_user
              @secret_credential_form = MfaSecretForm.new
              @secret_credential_hints = active_secret_credential_hints_for(mfa_user)
            else
              @secret_credential_form = SecretLoginForm.new
            end

            render_secret_new
          end

          def create
            if mfa_user
              handle_mfa_login
            else
              handle_standard_login
            end
          end

          def handle_mfa_login
            @secret_credential_form = MfaSecretForm.new(mfa_secret_credential_params)
            @secret_credential_form.turnstile_response = turnstile_response_param
            unless @secret_credential_form.valid?
              return render_failed_login(
                reason: :form_invalid,
                user: mfa_user,
                details: { errors: @secret_credential_form.errors.full_messages },
              )
            end
            unless cloudflare_turnstile_validation["success"]
              return render_failed_login(reason: :turnstile_failed, user: mfa_user)
            end

            user = mfa_user
            verification = verify_secret_credential_for_sign_in(
              user: user,
              raw_secret_credential: @secret_credential_form.secret_credential_value,
            )

            if user && verification.secret_credential
              handle_successful_mfa(user, verification.secret_credential)
            else
              handle_failed_mfa(user, verification.reason, verification.details)
            end
          rescue StandardError => e
            report_authentication_error(e, flow: "mfa_secret_credential")
            render_failed_login(reason: :internal_error, user: mfa_user, details: { error_class: e.class.name })
          end

          def handle_standard_login
            @secret_credential_form = SecretLoginForm.new(secret_credential_params)
            @secret_credential_form.turnstile_response = turnstile_response_param
            unless @secret_credential_form.valid?
              return render_failed_login(
                reason: :form_invalid,
                identifier: @secret_credential_form.identifier,
                details: { errors: @secret_credential_form.errors.full_messages },
              )
            end
            unless cloudflare_turnstile_validation["success"]
              return render_failed_login(reason: :turnstile_failed, identifier: @secret_credential_form.identifier)
            end

            user = find_user_by_identifier(@secret_credential_form.identifier)
            return render_session_limit_hard_reject if session_limit_hard_reject_for?(user)

            verification = verify_secret_credential_for_sign_in(
              user: user,
              raw_secret_credential: @secret_credential_form.secret_credential_value,
            )

            if user && verification.secret_credential
              process_standard_login(user)
            else
              failure_reason = verification.reason || :identifier_not_found
              render_failed_login(
                reason: failure_reason,
                identifier: @secret_credential_form.identifier,
                user: user,
                details: verification.details,
              )
            end
          rescue StandardError => e
            report_authentication_error(e, flow: "secret_credential")
            render_failed_login(
              reason: :internal_error,
              identifier: @secret_credential_form&.identifier,
              details: { error_class: e.class.name },
            )
          end

          def handle_successful_mfa(user, secret_credential)
            Rails.logger.info(
              JitLogEvent.format(
                "authentication.mfa.succeeded", user_id: user.id, ip_address: request.remote_ip,
                                                method: "secret_credential", secret_credential_id: secret_credential.id,
                                                ri: current_region_identifier,
              ),
            )
            clear_mfa_session!
            result = finalize_mfa_login!(user)
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
              render_failed_login(reason: result[:status], user: user)
            end
          end

          def handle_failed_mfa(user, reason, details = {})
            Rails.logger.info(
              JitLogEvent.format(
                "authentication.totp.failed", user_id: user&.id, ip_address: request.remote_ip,
                                              method: "secret_credential", ri: current_region_identifier,
              ),
            )
            @secret_credential_hints = active_secret_credential_hints_for(user) if user
            render_failed_login(reason: reason, user: user, details: details)
          end

          def process_standard_login(user)
            result = AuthenticationSessionCommitter.call(
              controller: self, resource: user, pt: nil, ri: current_region_identifier,
              auth_method: "secret_credential",
            )
            sign_in_result = sign_in_result_from_session_result(result, actor: user)
            if sign_in_result.mfa_required? || sign_in_result.session_limit_pending?
              redirect_to(sign_in_result.redirect_to)
            elsif sign_in_result.status == :session_limit_hard_reject
              render_session_limit_hard_reject(
                message: sign_in_result.message,
                http_status: sign_in_result.response_status,
              )
            else
              redirect_to_sign_in_sequence!(
                pt: signed_pt_param,
              )
            end
          end

          private

          def turnstile_response_param
            request.request_parameters["cf-turnstile-response"].to_s
          end

          def mfa_user
            return @mfa_user if defined?(@mfa_user)

            # MFA_USER_SESSION_KEY is the legacy alias written by set_pending_mfa!
            # alongside the TTL-bearing session[:pending_mfa] entry. Read on its own it
            # carries no timestamp, so a half-finished sign-in stayed completable for
            # the 14-day session cookie lifetime instead of the 10-minute pending-MFA
            # window. Gate on the TTL the way the passkey and TOTP challenge
            # controllers do (see Challenge::TotpsController#ensure_pending_mfa!).
            unless pending_mfa_valid?
              clear_mfa_session!
              @mfa_user = nil
              return nil
            end

            user_id = session[MFA_USER_SESSION_KEY]
            # Ensure user_id is clearly present before querying
            if user_id.blank?
              @mfa_user = nil
              return nil
            end

            @mfa_user = Client.find_by(id: user_id)
          end

          def clear_mfa_session!
            # Clear both the legacy alias and the pending-MFA entry it mirrors,
            # otherwise an expired ceremony leaves half its state behind.
            clear_pending_mfa!
          end

          def verify_secret_credential_for_sign_in(user:, raw_secret_credential:)
            return SecretVerificationResult.new(reason: :identifier_not_found, details: {}) unless user
            return SecretVerificationResult.new(
              reason: :verified_pii_missing,
              details: {},
            ) unless user.has_verified_pii?

            eligible = find_latest_eligible_secret_credential(user)
            return eligible unless eligible.secret_credential

            verification = perform_secret_credential_verification(eligible.secret_credential, raw_secret_credential)
            return wrap_verification_failure(
              verification,
              eligible.secret_credential,
            ) unless verification.secret_credential

            secret_credential = verification.secret_credential || eligible.secret_credential
            audit_recovery_secret_credential_if_recovery!(user, secret_credential)
            SecretVerificationResult.new(
              secret_credential: secret_credential,
              reason: :success,
              details: { secret_credential_id: secret_credential.id },
            )
          end

          def find_latest_eligible_secret_credential(user)
            latest = user.client_secret_credentials.order(created_at: :desc).first
            return SecretVerificationResult.new(reason: :secret_credential_not_found, details: {}) unless latest

            eligible = user.client_secret_credentials
              .allowed_for_secret_credential_sign_in
              .order(created_at: :desc)
              .first
            unless eligible
              return SecretVerificationResult.new(
                reason: :secret_credential_expired,
                details: {
                  latest_secret_credential_id: latest.id,
                  latest_status_id: latest.user_secret_status_id,
                  latest_kind_id: latest.user_secret_kind_id,
                },
              )
            end
            unless eligible.usable_for_secret_credential_sign_in?
              return SecretVerificationResult.new(
                reason: :secret_credential_expired,
                details: {
                  secret_credential_id: eligible.id,
                  uses_remaining: eligible.uses_remaining,
                  expires_at: eligible.expires_at,
                },
              )
            end

            SecretVerificationResult.new(secret_credential: eligible, reason: :success, details: {})
          end

          def perform_secret_credential_verification(secret_credential, raw_secret_credential)
            if secret_credential.new_axis_secret_credential?
              ::SignSecretVerify.call(
                secret_credential: secret_credential,
                raw_secret_credential: raw_secret_credential.to_s,
              )
            else
              verified = secret_credential.verify_for_secret_credential_sign_in!(raw_secret_credential.to_s)
              SecretVerificationResult.new(
                secret_credential: verified ? secret_credential : nil,
                reason: verified ? :success : :secret_credential_mismatch,
                details: { secret_credential_id: secret_credential.id },
              )
            end
          end

          def wrap_verification_failure(verification, secret_credential)
            SecretVerificationResult.new(
              reason: verification.reason || :secret_credential_mismatch,
              details: verification.details.presence || { secret_credential_id: secret_credential.id },
            )
          end

          def audit_recovery_secret_credential_if_recovery!(user, secret_credential)
            audit_recovery_code_used!(user, secret_credential) if secret_credential.recovery_secret_credential?
          end

          def active_secret_credential_hints_for(user)
            user.client_secret_credentials
              .allowed_for_secret_credential_sign_in
              .order(created_at: :desc)
              .limit(10)
              .filter_map { |s| s.name.to_s.first(4) if s.usable_for_secret_credential_sign_in? }
          end

          def secret_credential_params
            params.fetch(:secret_credential_login_form, {}).permit(
              :identifier,
              :secret_credential_value,
            )
          end

          def mfa_secret_credential_params
            params.fetch(:mfa_secret_credential_form, {}).permit(:secret_credential_value)
          end

          def invalid_secret_credential_message
            t("sign.app.authentication.secret_credential.create.invalid")
          end

          def report_authentication_error(error, flow:)
            Rails.logger.error(
              JitLogEvent.format(
                "sign.authentication.secret_credential.error",
                flow: flow,
                error_class: error.class.name,
                message: error.message,
                user_id: mfa_user&.id,
                ip: request.remote_ip,
                ri: current_region_identifier,
                exception: error,
              ),
            )
          end

          def render_failed_login(reason:, identifier: nil, user: nil, details: {})
            @secret_credential_form.errors.add(:base, invalid_secret_credential_message)

            # Detailed failure logging (failure_reason=...) as requested
            Rails.logger.info(
              JitLogEvent.format(
                "sign.authentication.secret_credential.failed",
                reason: reason,
                identifier_type: detect_identifier_type(identifier.to_s),
                identifier_present: identifier.present?,
                user_id: user&.id,
                ip: request.remote_ip,
                ri: current_region_identifier,
                errors: @secret_credential_form.errors.full_messages,
                details: details,
              ),
            )

            SignRiskEmitter.emit("auth_failed", user_id: user&.id) if user

            render_new_with_unprocessable_content
          end

          def minimum_response_budget_enabled?
            action_name == "create"
          end

          def render_new_with_unprocessable_content
            render_secret_new(status: :unprocessable_content)
          end

          # Named rather than derived: `create` re-renders this same page on every failure branch.
          def render_secret_new(status: :ok)
            render inertia: "auth/app/sign/in/secrets/new",
                   props: secret_new_props,
                   status: status,
                   formats: :html
          end

          def secret_new_props
            scope = "sign.app.authentication.secret_credential.new"
            pt = signed_pt_param
            ri = current_region_identifier

            {
              title: page_t("#{scope}.page_title"),
              form: {
                action: auth_app_sign_in_secret_path,
                method: "post",
                pt: pt,
                ri: ri,
                identifier_field: secret_identifier_field(scope),
                secret_field: {
                  scope: secret_form_param_key,
                  field: "secret_credential_value",
                  name: "#{secret_form_param_key}[secret_credential_value]",
                  label: page_t("#{scope}.secret_credential_label"),
                  placeholder: "••••••••••••••••",
                },
                submit_label: t("actions.submit"),
              },
              hints: secret_credential_hints_prop(scope),
              error_heading: t("errors.messages.validation_failed"),
              form_errors: @secret_credential_form.errors.full_messages,
              turnstile: turnstile_visible_props,
              back_link: {
                label: t("sign.app.authentication.new.back"),
                href: auth_app_sign_in_path(pt: pt, ri: ri),
              },
            }
          end

          # The second-factor form identifies the actor from the pending MFA session, so it carries
          # no identifier field at all rather than one React would hide.
          def secret_identifier_field(scope)
            return nil unless @secret_credential_form.respond_to?(:identifier)

            {
              scope: secret_form_param_key,
              field: "identifier",
              name: "#{secret_form_param_key}[identifier]",
              label: page_t("#{scope}.pii_label"),
              placeholder: page_t("#{scope}.pii_placeholder"),
            }
          end

          def secret_credential_hints_prop(scope)
            return nil if @secret_credential_hints.blank?

            { label: page_t("#{scope}.hints"), value: @secret_credential_hints.join(", ") }
          end

          def secret_form_param_key
            @secret_credential_form.class.model_name.param_key
          end

          def audit_recovery_code_used!(user, secret_credential)
            ChronicleRecord.connected_to(role: :writing) do
              ClientChronicleEvent.find_or_create_by!(id: ClientChronicleEvent::RECOVERY_CODE_USED)
              ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
            end

            ClientChronicle.create!(
              actor_type: "Client",
              actor_id: user.id,
              event_id: ClientChronicleEvent::RECOVERY_CODE_USED,
              subject_id: secret_credential.id.to_s,
              subject_type: "ClientSecretCredential",
              occurred_at: Time.current,
            )
          end
        end
      end
    end
  end
end
