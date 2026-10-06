# typed: false
# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength

module Auth
  module Com
    module Sign
      module Up
        class EmailsController < ::Auth::Com::ApplicationController
          include ::SurfaceInertiaPage

          include ::TurnstilePageProps

          include ::CloudflareTurnstile

          include CommonRedirect

          include CommonOtp

          include EnforcementIdentifierGate

          include SignUpSuspensionGuard
          include SignUpFlowEntry

          AUTHENTICATION_MODE = :guest

          SESSION_KEY = :auth_com_up_email_flow_state
          before_action :reject_suspended_sign_up!

          before_action :enforce_email_flow!

          # Defence-in-depth for sign-up entry. Tighten OTP fanout from a single
          # source and from repeated attempts against the same email digest.
          rate_limit(
            to: RateLimitProfiles.interactive_post_ip.to,
            within: RateLimitProfiles.interactive_post_ip.within,
            by: -> { "sign_up_email_ip:#{request.remote_ip}" },
            with: -> {
              render_rate_limited(retry_after: RateLimitProfiles.interactive_post_ip.retry_after)
            },
            store: rate_limit_store,
            name: "ip_burst",
            scope: "auth_com_sign_up_email",
            only: :create,
          )
          rate_limit(
            to: RateLimitProfiles.email_address_submit.to,
            within: RateLimitProfiles.email_address_submit.within,
            by: -> {
              digest = sign_up_email_digest_for_rate_limit
              "sign_up_email_addr:#{digest}"
            },
            if: -> { sign_up_email_digest_for_rate_limit.present? },
            with: -> {
              render_rate_limited(retry_after: RateLimitProfiles.email_address_submit.retry_after)
            },
            store: rate_limit_store,
            name: "email_sustained",
            scope: "auth_com_sign_up_email",
            only: :create,
          )

          def new
            @user_email = VisitorEmail.new
            sign_up_flow_locator.clear!
            render_sign_up_email_new
          end

          def create
            supersede_active_sign_up_flow!

            unless cloudflare_turnstile_validation["success"]
              @user_email = VisitorEmail.new
              @user_email.errors.add(
                :base,
                t("sign.com.registration.email.create.turnstile_validation_failed"),
              )
              render_sign_up_email_new(status: :unprocessable_content)
              return
            end

            email_params = params.slice(:visitor_email).permit(
              visitor_email: %i(raw_address address confirm_policy
                                notifiable),
            )[:visitor_email]
            email_address = email_params&.[](:raw_address).presence || email_params&.[](:address).presence

            if email_address.blank?
              @user_email = VisitorEmail.new
              @user_email.errors.add(
                :base,
                t("sign.com.registration.email.create.address_required"),
              )
              render_sign_up_email_new(status: :unprocessable_content)
              return
            end

            # adr/unified-enforcement.md, Signup enforcement: an in-force Identifier
            # Effect with registration_blocked rejects signup before any OTP is sent,
            # at the same enumeration-resistance discipline as an ordinary validation
            # failure -- same render call, same error copy, no distinguishing signal.
            if enforcement_blocks_email_registration?(
              effect_class: ComEnforcementIdentifierEffect, realm: "com", email: email_address,
            )
              @user_email = VisitorEmail.new
              @user_email.errors.add(
                :base,
                t("sign.com.registration.email.create.address_required"),
              )
              render_sign_up_email_new(status: :unprocessable_content)
              return
            end

            result = initiate_visitor_email_verification!(
              email_address,
              confirm_policy: email_params[:confirm_policy],
              email_preferences: email_params.slice(:notifiable),
            )
            if result == :cooldown
              render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
              return
            end

            unless result
              strip_visitor_owner_errors!
              render_sign_up_email_new(status: :unprocessable_content)
              return
            end

            bind_sign_up_flow_to_email!(@user_email)
            progress_email_flow!(:create)
            redirect_to(
              auth_com_sign_up_check_email_otp_path(
                **sign_up_flow_binding_params, ri: params[:ri],
                                               pt: sanitized_rt_param,
              ),
            )
          end

          private

          def sign_up_surface = :com

          def email_otp_purpose = :sign_up

          # The registration form. `pt` travels in the generated action URL rather than as a prop,
          # so the signed target never becomes page data the browser holds separately.
          def render_sign_up_email_new(status: :ok)
            render inertia: "auth/com/sign/up/emails/new",
                   props: sign_up_email_new_props,
                   status: status
          end

          def sign_up_email_new_props
            errors = sign_up_email_errors

            {
              title: t("sign.com.registration.email.new.page_title"),
              action: auth_com_sign_up_email_path(pt: signed_pt_param),
              scope: "visitor_email",
              field: {
                name: "raw_address",
                label: VisitorEmail.human_attribute_name(:address),
                type: "email",
                autocomplete: "email",
                value: sign_up_email_input_value,
              },
              checkboxes: [
                {
                  name: "confirm_policy",
                  label: t("views.sign.com.up.emails.new.confirm_policy_label"),
                  description: nil,
                },
                {
                  name: "notifiable",
                  label: t("sign.com.settings.email.edit.notifiable_label"),
                  description: t("sign.com.settings.email.edit.notifiable_description"),
                },
              ],
              error_heading: errors.any? ? t("sign.com.registration.email.new.error_summary") : nil,
              errors: errors,
              turnstile: turnstile_visible_props,
              submit_label: sign_up_email_submit_label,
              links: [
                {
                  key: "other_methods",
                  label: t("sign.app.registration.new.page_title"),
                  href: auth_com_sign_up_path(ri: params[:ri]),
                },
                {
                  key: "sign_in",
                  label: t("sign.app.registration.email.new.link_to_sign_in"),
                  href: auth_com_sign_in_path(ri: params[:ri]),
                },
              ],
            }
          end

          # The OTP step. Only what the page shows crosses: never the code, the ceremony nonce or
          # the address the server already holds in the flow.
          def render_sign_up_email_edit(status: :ok)
            render inertia: "auth/com/sign/up/emails/edit",
                   props: sign_up_email_edit_props,
                   status: status
          end

          def sign_up_email_edit_props
            {
              title: t("sign.app.authentication.email.edit.page_title"),
              description: t("sign.app.registration.email.create.verification_code_sent"),
              action: auth_com_sign_up_check_email_otp_path(
                **sign_up_flow_binding_params, ri: params[:ri],
                                               pt: signed_pt_param,
              ),
              scope: "visitor_email",
              code_label: t("sign.app.authentication.email.edit.code_label"),
              code_placeholder: t("sign.app.authentication.email.edit.code_placeholder"),
              submit_label: t("sign.app.authentication.email.edit.submit"),
              delivery_help: t("sign.app.authentication.email.edit.delivery_help"),
              turnstile: turnstile_visible_props(challenge_id: SecureRandom.uuid),
              error_heading: nil,
              errors: sign_up_email_errors,
              # The code has been sent and a ticket exists, so /sign/up is not a step back: the only exit
              # ends the sign-up through the existing DELETE cancellation.
              cancel: { label: t("actions.cancel"),
                        action: auth_com_sign_up_check_email_otp_path(**sign_up_flow_binding_params, ri: params[:ri]),
                        method: "delete", },
            }
          end

          def sign_up_email_errors
            @user_email&.errors&.map(&:full_message) || []
          end

          def sign_up_email_input_value
            return "" unless request.post?

            email_params = params.slice(:visitor_email).permit(
              visitor_email: %i(raw_address address confirm_policy notifiable),
            )[:visitor_email]
            value = email_params&.[](:raw_address)
            value = email_params&.[](:address) unless value.is_a?(String)
            value if value.is_a?(String)
          end

          # Mirrors the label `form.submit` looked up, so the button keeps its wording.
          def sign_up_email_submit_label
            I18n.t(
              :"helpers.submit.#{VisitorEmail.model_name.param_key}.create",
              model: VisitorEmail.model_name.human,
              default: [:"helpers.submit.create", "Create %{model}"],
            )
          end

          def enforce_email_flow!
            requirements = { new: "init", create: "init", edit: "email_created" }
            required = requirements[action_name.to_sym]
            return unless required

            current = email_flow_state
            if %i(new create).include?(action_name.to_sym) && current != "init"
              reset_email_flow!
              return
            end
            return if current == required

            redirect_to(new_auth_com_sign_up_email_path(ri: params[:ri]))
          end

          def email_flow_state
            state = session[SESSION_KEY].to_s
            state = "init" unless %w(init email_created email_verified).include?(state)
            session[SESSION_KEY] = state
          end

          def progress_email_flow!(action)
            next_state = { create: "email_created", update: "email_verified" }[action.to_sym]
            session[SESSION_KEY] = next_state if next_state
          end

          def reset_email_flow!
            session[SESSION_KEY] = "init"
            sign_up_flow_locator.clear!
          end

          def redirect_invalid_session
            reset_email_flow!
            redirect_to(new_auth_com_sign_up_email_path(ri: params[:ri]))
          end

          def valid_email_session?
            return false if @user_email.blank?
            return false if @user_email.otp_expired?

            @user_email.visitor_email_status_id == VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP
          end

          def initiate_visitor_email_verification!(email_address, confirm_policy: "1", email_preferences: {})
            @user_email = VisitorEmail.new(
              { raw_address: email_address, confirm_policy: confirm_policy }.merge(email_preferences),
            )
            @user_email.visitor_email_status_id = VisitorEmailStatus::UNVERIFIED_WITH_SIGN_UP
            @user_email.validate

            return false if @user_email.address_digest.blank?

            SignUpEmailPendingGuard.with_lock(
              address_digest: @user_email.address_digest,
              model_class: VisitorEmail,
            ) do
              cleanup_pending_visitor_signup!
              next false if @user_email.errors.details.except(:visitor, :visitor_id).any?

              pending_visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
              @user_email.visitor = pending_visitor
              otp_number = generate_otp_attributes(@user_email)
              @user_email.otp_last_sent_at = Time.current
              @user_email.save!
              token = @user_email.generate_verification_token
              OtpAdapter.for(surface: :com, channel: :email).deliver(
                record: @user_email,
                otp_code: otp_number,
                purpose: :sign_up,
                verification_token: token, public_id: @user_email.public_id,
              )

              true
            end
          rescue ActiveRecord::RecordInvalid => e
            @user_email = e.record if e.record.is_a?(VisitorEmail)
            strip_visitor_owner_errors!
            false
          end

          def cleanup_pending_visitor_signup!
            cycle = sign_up_flow_locator.current
            return unless cycle&.principal_id

            Visitor.find_by(id: cycle.principal_id)&.destroy!
          end

          def sanitized_rt_param
            signed_pt_token(path_target_value)
          end

          # Derives a per-address rate-limit bucket. Uses the same SHA-256
          # digest the model stores so concurrent normalisations resolve to
          # the same bucket. Returns nil for blank input -- the rate_limit
          # lambda decides how to handle that case.
          def sign_up_email_digest_for_rate_limit
            raw = params.dig(:visitor_email, :raw_address) ||
              params.dig(:visitor_email, :address) ||
              params.dig(:user_email, :raw_address) ||
              params.dig(:user_email, :address)
            return nil if raw.blank?

            normalized = JitUtilsEmailValidator.normalize(raw)
            return nil if normalized.blank?

            Digest::SHA256.hexdigest(normalized)
          end

          def strip_visitor_owner_errors!
            return if @user_email.blank?

            @user_email.errors.delete(:visitor)
            @user_email.errors.delete(:visitor_id)
          end

          def current_registration_email
            cycle = sign_up_flow_locator.current
            return unless cycle&.pending_contact_type == "email"

            VisitorEmail.find_by(id: cycle.pending_contact_id)
          end

          def issue_sign_up_flow!
            sign_up_flow_locator.issue!(
              VisitorSignUpFlow.create!(
                principal_id: nil,
                status_id: VisitorSignUpFlowStatus::STARTED,
                step: "start",
                nonce_digest: VisitorSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
                issued_at: Time.current,
                expires_at: VisitorSignUpFlow.default_ttl.from_now,
                entry_method: "email",
                return_to: sanitized_return_to,
              ),
            )
          end

          def current_sign_up_flow
            sign_up_flow_locator.current || issue_sign_up_flow!
          end

          def bind_sign_up_flow_to_email!(email)
            cycle = current_sign_up_flow
            ComTicketRecord.connected_to(role: :writing) do
              cycle.update!(
                principal_id: email.visitor_id,
                pending_contact_type: "email",
                pending_contact_id: email.id,
              )
              SignUpStateMachine.call(ticket: cycle, event: :submit_contact, actor_context: Actor.authn)
            end
            session[:auth_com_up_sequence_id] = cycle.public_id
          end

          def sign_up_flow_locator
            SignUpCycleLocator.new(session, surface: :com, cycle_class: VisitorSignUpFlow)
          end

          def sanitized_return_to
            resolved_path_or_navigation_target
          end
        end
      end
    end
  end
end
