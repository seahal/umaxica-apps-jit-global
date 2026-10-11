# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        # Second stage of Normal org sign-in, for an Operator whose Passkey is
        # lost. Entra ID has already identified them, so this ceremony never
        # asks who is signing in: the pending Entra transaction names the
        # Operator and the secret is verified against that Operator alone.
        #
        # The secret verification itself is unchanged -- the same
        # `staff_secret_credentials` scopes and the same SignSecretVerify /
        # `verify_for_secret_credential_sign_in!` path as before. Only the
        # actor's source moved.
        class SecretsController < ::Auth::Org::ApplicationController
          include ::CloudflareTurnstile
          include ::OrgNormalSignInTransaction
          include ::AuthenticationModeSwitchGuard

          include ::TurnstilePageProps
          include ::SurfaceInertiaPage

          include MinimumResponseBudget

          include SessionLimitGate

          AUTHENTICATION_MODE = :guest

          SecretVerificationResult = Struct.new(:secret_credential, :reason, :details, keyword_init: true)

          rate_limit(
            to: 5,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "auth_org_sign_in",
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
            scope: "auth_org_sign_in",
            name: "secret_credential_create_ip_sustained",
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
                surface: :org,
                identifier: org_normal_sign_in_transaction&.dig(:operator_id),
              )
            },
            scope: "auth_org_sign_in",
            name: "secret_credential_create_actor",
            store: rate_limit_store,
            only: :create,
            with: -> {
              render_rate_limited(retry_after: 900)
            },
          )
          before_action :require_org_normal_sign_in_transaction!
          before_action :start_minimum_response_budget
          after_action :enforce_minimum_response_budget

          # No identifier: the Operator is the one the Entra transaction
          # selected, and a submitted identifier must not be able to change it.
          class SecretLoginForm
            include ActiveModel::Model

            attr_accessor :secret_credential_value

            validates :secret_credential_value, presence: true

            def self.model_name
              ActiveModel::Name.new(self, nil, "secret_credential_login_form")
            end
          end

          def new
            @secret_credential_form = SecretLoginForm.new
            render inertia: true, props: secret_sign_in_props
          end

          def create
            @secret_credential_form = SecretLoginForm.new(secret_credential_params)
            unless @secret_credential_form.valid?
              return render_failed_login(:form_invalid)
            end

            unless cloudflare_turnstile_validation["success"]
              return render_failed_login(:turnstile_failed)
            end

            staff = org_normal_sign_in_operator
            return render_session_limit_hard_reject if session_limit_hard_reject_for?(staff)

            verification = verify_secret_credential_for_sign_in(
              staff: staff,
              raw_secret_credential: @secret_credential_form.secret_credential_value,
            )

            if staff && verification.secret_credential
              process_standard_login(staff)
            else
              render_failed_login(verification.reason || :identifier_not_found)
            end
          rescue StandardError => e
            Rails.logger.error(
              JitLogEvent.format(
                "sign.org.authentication.secret_credential.error",
                error_class: e.class.name,
                message: e.message,
                ip: request.remote_ip,
                ri: current_region_identifier,
                exception: e,
              ),
            )
            render_failed_login(:internal_error)
          end

          private

          # Entra success alone establishes no session, and the secret stage
          # alone authenticates nobody. Without the pending transaction there is
          # no Operator to verify against, so the ceremony is refused.
          def require_org_normal_sign_in_transaction!
            return if org_normal_sign_in_operator.present?

            clear_org_normal_sign_in_transaction!
            if request.get? || request.head?
              redirect_to(auth_org_sign_in_path(ri: current_region_identifier), status: :see_other)
            else
              render plain: I18n.t("errors.messages.invalid_request"), status: :unprocessable_content
            end
          end

          def verify_secret_credential_for_sign_in(staff:, raw_secret_credential:)
            return SecretVerificationResult.new(reason: :identifier_not_found) unless staff

            latest_secret_credential = staff.staff_secret_credentials.order(created_at: :desc).first
            return SecretVerificationResult.new(reason: :secret_credential_not_found) unless latest_secret_credential

            secret_credential = staff.staff_secret_credentials
              .allowed_for_secret_credential_sign_in
              .order(created_at: :desc)
              .first
            return SecretVerificationResult.new(reason: :secret_credential_not_found) unless secret_credential
            return SecretVerificationResult.new(reason: :secret_credential_expired) unless
              secret_credential.usable_for_secret_credential_sign_in?

            verification =
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

            unless verification.secret_credential
              return SecretVerificationResult.new(
                reason: verification.reason || :secret_credential_mismatch,
                details: verification.details.presence || { secret_credential_id: secret_credential.id },
              )
            end

            SecretVerificationResult.new(secret_credential: secret_credential, reason: :success)
          end

          def process_standard_login(staff)
            transaction = consume_org_normal_sign_in_transaction!
            pt = transaction&.dig(:pt).presence || signed_pt_param
            result = establish_signed_in_session!(
              staff, pt: pt, ri: current_region_identifier, auth_method: "secret_credential",
                     authentication_context: AuthenticationContextValue::NORMAL_KEY,
            )
            sign_in_result = sign_in_result_from_session_result(result, actor: staff)

            if sign_in_result.mfa_required? || sign_in_result.session_limit_pending?
              redirect_to(sign_in_result.redirect_to)
            elsif sign_in_result.status == :session_limit_hard_reject
              render_session_limit_hard_reject(
                message: sign_in_result.message,
                http_status: sign_in_result.response_status,
              )
            elsif sign_in_result.success?
              redirect_to_sign_in_sequence!(
                pt: pt,
              )
            else
              render_failed_login(sign_in_result.status)
            end
          end

          def render_failed_login(reason)
            @secret_credential_form ||= SecretLoginForm.new
            @secret_credential_form.errors.add(:base, invalid_secret_credential_message)

            staff = org_normal_sign_in_operator

            Rails.logger.info(
              JitLogEvent.format(
                "sign.org.authentication.secret_credential.failed",
                reason: reason,
                staff_id: staff&.id,
                ip: request.remote_ip,
                ri: current_region_identifier,
                errors: @secret_credential_form.errors.full_messages,
              ),
            )

            SignRiskEmitter.emit("auth_failed", staff_id: staff&.id) if staff

            render inertia: "auth/org/sign/in/secrets/new",
                   props: secret_sign_in_props,
                   status: :unprocessable_content
          end

          def secret_sign_in_props
            pt = signed_pt_param
            region = current_region_identifier
            scope = "sign.org.authentication.secret_credential.new"

            {
              title: page_t("#{scope}.page_title"),
              form_action: auth_org_sign_in_secret_path,
              hidden_fields: { pt: pt.presence, ri: region.to_s },
              errors_title: t("errors.messages.validation_failed"),
              errors: @secret_credential_form.errors.full_messages,
              secret: {
                name: "secret_credential_login_form[secret_credential_value]",
                label: page_t("#{scope}.secret_credential_label"),
                placeholder: "••••••••••••••••",
              },
              submit_label: t("actions.submit"),
              back_link: {
                label: t("sign.org.authentication.new.back"),
                href: auth_org_sign_in_path(pt: pt, ri: region),
              },
              turnstile: turnstile_visible_props,
            }
          end

          def invalid_secret_credential_message
            t("sign.org.authentication.secret_credential.create.invalid")
          end

          def secret_credential_params
            params.fetch(:secret_credential_login_form, {}).permit(:secret_credential_value)
          end

          def minimum_response_budget_enabled?
            action_name == "create"
          end
        end
      end
    end
  end
end
