# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module In
        class SecretsController < ::Auth::Com::ApplicationController
          include ::AuthenticationModeSwitchGuard
          include ::CloudflareTurnstile

          include EmailValidation

          include IdentifierDetection

          include CommonRedirect

          include MinimumResponseBudget

          include SessionLimitGate
          include ::SurfaceInertiaPage
          include ::TurnstilePageProps

          AUTHENTICATION_MODE = :guest

          SecretVerificationResult = Struct.new(:secret_credential, :reason, :details, keyword_init: true)

          rate_limit(
            to: 5,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "auth_com_sign_in",
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
            scope: "auth_com_sign_in",
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
                surface: :com,
                identifier: request.request_parameters.dig("secret_credential_login_form", "identifier"),
              )
            },
            scope: "auth_com_sign_in",
            name: "secret_credential_create_identifier",
            store: rate_limit_store,
            only: :create,
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

          def new
            @secret_credential_form = SecretLoginForm.new
            render inertia: true, props: sign_in_secret_new_props
          end

          def create
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

            visitor = find_user_by_identifier(@secret_credential_form.identifier)
            return render_session_limit_hard_reject if session_limit_hard_reject_for?(visitor)

            verification = verify_secret_credential_for_sign_in(
              visitor: visitor,
              raw_secret_credential: @secret_credential_form.secret_credential_value,
            )

            if visitor && verification.secret_credential
              process_standard_login(visitor)
            else
              failure_reason = verification.reason || :identifier_not_found
              render_failed_login(
                reason: failure_reason,
                identifier: @secret_credential_form.identifier,
                visitor: visitor,
                details: verification.details,
              )
            end
          rescue StandardError => e
            Rails.logger.error(
              JitLogEvent.format(
                "sign.com.authentication.secret_credential.error",
                error_class: e.class.name,
                message: e.message,
                ip: request.remote_ip,
                ri: current_region_identifier,
                exception: e,
              ),
            )
            render_failed_login(
              reason: :internal_error,
              identifier: @secret_credential_form&.identifier,
              details: { error_class: e.class.name },
            )
          end

          private

          def sign_in_secret_new_props
            pt = signed_pt_param
            ri = current_region_identifier

            {
              title: t("sign.app.authentication.secret_credential.new.page_title"),
              action: auth_com_sign_in_secret_path,
              pt: pt,
              ri: ri,
              validation_failed_title: t("errors.messages.validation_failed"),
              identifier_label: t("sign.app.authentication.secret_credential.new.pii_label"),
              identifier_placeholder: t("sign.app.authentication.secret_credential.new.pii_placeholder"),
              secret_label: t("sign.app.authentication.secret_credential.new.secret_credential_label"),
              submit_label: t("actions.submit"),
              back_link: {
                label: t("sign.app.authentication.new.back"),
                href: auth_com_sign_in_path(pt: pt, ri: ri),
              },
              turnstile: turnstile_visible_props,
            }
          end

          def identity_email_model
            VisitorEmail
          end

          def identity_telephone_model
            VisitorTelephone
          end

          def identity_from_email_record(record)
            record&.visitor
          end

          def identity_from_telephone_record(record)
            record&.visitor
          end

          def verify_secret_credential_for_sign_in(visitor:, raw_secret_credential:)
            return SecretVerificationResult.new(reason: :identifier_not_found, details: {}) unless visitor
            return SecretVerificationResult.new(
              reason: :verified_pii_missing,
              details: {},
            ) unless visitor.has_verified_pii?

            latest = visitor.visitor_secret_credentials.order(created_at: :desc).first
            return SecretVerificationResult.new(reason: :secret_credential_not_found, details: {}) unless latest

            secret_credential = visitor.visitor_secret_credentials
              .allowed_for_secret_credential_sign_in
              .order(created_at: :desc)
              .first
            unless secret_credential&.usable_for_secret_credential_sign_in?
              return SecretVerificationResult.new(reason: :secret_credential_expired, details: {})
            end

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

            SecretVerificationResult.new(
              secret_credential: secret_credential, reason: :success,
              details: { secret_credential_id: secret_credential.id },
            )
          end

          def process_standard_login(visitor)
            result = establish_signed_in_session!(
              visitor, pt: nil, ri: current_region_identifier, auth_method: "secret_credential",
            )
            sign_in_result = sign_in_result_from_session_result(result, actor: visitor)

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

          def secret_credential_params
            params.fetch(:secret_credential_login_form, {}).permit(:identifier, :secret_credential_value)
          end

          def turnstile_response_param
            request.request_parameters["cf-turnstile-response"].to_s
          end

          def invalid_secret_credential_message
            t("sign.app.authentication.secret_credential.create.invalid")
          end

          def render_failed_login(reason:, identifier: nil, visitor: nil, details: {})
            @secret_credential_form ||= SecretLoginForm.new
            @secret_credential_form.errors.add(:base, invalid_secret_credential_message)

            Rails.logger.info(
              JitLogEvent.format(
                "sign.com.authentication.secret_credential.failed",
                reason: reason,
                identifier_type: detect_identifier_type(identifier.to_s),
                identifier_present: identifier.present?,
                visitor_id: visitor&.id,
                ip: request.remote_ip,
                ri: current_region_identifier,
                errors: @secret_credential_form.errors.full_messages,
                details: details,
              ),
            )

            SignRiskEmitter.emit("auth_failed", visitor_id: visitor&.id) if visitor

            # A rejected attempt re-renders this page with 422 and the errors the page reads, so the
            # rejection stays a response to this request rather than a redirect the client could
            # replay. The message stays the same single message for every reason.
            render(
              inertia: "auth/com/sign/in/secrets/new",
              props: sign_in_secret_new_props.merge(
                errors: @secret_credential_form.errors.to_hash(true).transform_values(&:first),
              ),
              status: :unprocessable_content,
              formats: :html,
            )
          end

          def minimum_response_budget_enabled?
            action_name == "create"
          end
        end
      end
    end
  end
end
