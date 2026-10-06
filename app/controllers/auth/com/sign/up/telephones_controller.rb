# typed: false
# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength

module Auth
  module Com
    module Sign
      module Up
        class TelephonesController < ::Auth::Com::ApplicationController
          include ::SurfaceInertiaPage

          include ::TurnstilePageProps

          include CloudflareTurnstile

          include CommonRedirect

          include CommonOtp

          include EnforcementIdentifierGate

          include SignUpSuspensionGuard
          include SignUpFlowEntry

          AUTHENTICATION_MODE = :guest

          before_action :reject_suspended_sign_up!

          def new
            @visitor_telephone = VisitorTelephone.new
            session[:visitor_telephone_registration] = nil
            sign_up_flow_locator.clear!
            render_sign_up_telephone_new
          end

          def create
            supersede_active_sign_up_flow!

            telephone_params = params.fetch(:visitor_telephone, {}).permit(
              :raw_number, :number, :confirm_policy, :confirm_using_mfa,
            )
            if telephone_params.blank?
              @visitor_telephone = VisitorTelephone.new
              @visitor_telephone.errors.add(:raw_number, :blank)
              render_sign_up_telephone_new(status: :unprocessable_content)
              return
            end

            # adr/unified-enforcement.md, Signup enforcement: an in-force Identifier
            # Effect with registration_blocked rejects signup before turnstile/OTP
            # work happens, at the same enumeration-resistance discipline as an
            # ordinary validation failure.
            raw_number = telephone_params[:raw_number].presence || telephone_params[:number].presence
            if raw_number.present? && enforcement_blocks_telephone_registration?(
              effect_class: ComEnforcementIdentifierEffect, realm: "com", telephone: raw_number,
            )
              @visitor_telephone = VisitorTelephone.new
              @visitor_telephone.errors.add(:raw_number, :blank)
              render_sign_up_telephone_new(status: :unprocessable_content)
              return
            end

            @visitor_telephone = VisitorTelephone.new(telephone_params || {})

            res = cloudflare_turnstile_validation

            unless res["success"]
              @visitor_telephone.errors.add(
                :base,
                t("sign.app.registration.telephone.create.turnstile_validation_failed"),
              )
              render_sign_up_telephone_new(status: :unprocessable_content)
              return
            end

            @visitor_telephone.validate

            has_errors = @visitor_telephone.errors.details.except(:visitor, :visitor_id).any?

            if has_errors
              render_sign_up_telephone_new(status: :unprocessable_content)
              return
            end

            result = SignComUpTelephoneSignupCreator.call(
              telephone: @visitor_telephone,
              pending_public_id: session_public_id_from_registration,
            )

            @visitor_telephone = result.telephone
            session[:visitor_telephone_registration] = result.session_payload
            bind_sign_up_flow_to_telephone!(@visitor_telephone)
            redirect_to(
              auth_com_sign_up_check_telephone_otp_path(**sign_up_flow_binding_params, ri: params[:ri]),
            )
          rescue ActiveRecord::RecordInvalid
            render_sign_up_telephone_new(status: :unprocessable_content)
          end

          private

          def sign_up_surface = :com

          # The registration form. `pt` travels in the generated action URL rather than as a prop,
          # so the signed target never becomes page data the browser holds separately.
          def render_sign_up_telephone_new(status: :ok)
            render inertia: "auth/com/sign/up/telephones/new",
                   props: sign_up_telephone_new_props,
                   status: status
          end

          def sign_up_telephone_new_props
            {
              title: t("sign.app.registration.telephone.new.page_title"),
              action: auth_com_sign_up_telephone_path(ri: params[:ri]),
              scope: "visitor_telephone",
              field: {
                name: "raw_number",
                label: VisitorTelephone.human_attribute_name(:number),
                type: "tel",
                autocomplete: "tel",
              },
              checkboxes: [
                {
                  name: "confirm_policy",
                  label: t("views.sign.com.up.telephones.new.confirm_policy_label"),
                  description: nil,
                },
                {
                  name: "confirm_using_mfa",
                  label: t("views.sign.com.up.telephones.new.confirm_using_mfa_label"),
                  description: nil,
                },
              ],
              # The ERB listed the messages without a heading above them.
              error_heading: nil,
              errors: sign_up_telephone_errors,
              turnstile: turnstile_visible_props,
              submit_label: sign_up_telephone_submit_label,
              links: [
                {
                  key: "other_methods",
                  label: t("sign.app.registration.telephone.new.link_to_other_methods"),
                  href: auth_com_sign_up_path(ri: params[:ri]),
                },
                {
                  key: "sign_in",
                  label: t("sign.app.registration.telephone.new.link_to_sign_in"),
                  href: auth_com_sign_in_path(ri: params[:ri]),
                },
              ],
            }
          end

          # The OTP step. Only what the page shows crosses: never the code, the ceremony nonce or
          # the number the server already holds in the flow.
          def render_sign_up_telephone_edit(status: :ok)
            render inertia: "auth/com/sign/up/telephones/edit",
                   props: sign_up_telephone_edit_props,
                   status: status
          end

          def sign_up_telephone_edit_props
            {
              title: t("sign.app.registration.telephone.edit.page_title"),
              description: t("sign.app.registration.telephone.create.verification_code_sent"),
              action: auth_com_sign_up_check_telephone_otp_path(**sign_up_flow_binding_params, ri: params[:ri]),
              scope: "visitor_telephone",
              code_label: t("sign.app.registration.telephone.edit.code_label"),
              code_placeholder: t("sign.app.registration.telephone.edit.code_placeholder"),
              submit_label: t("sign.app.registration.telephone.edit.submit"),
              delivery_help: t("sign.app.registration.telephone.edit.delivery_help"),
              error_heading: nil,
              errors: sign_up_telephone_errors,
              # The code has been sent and a ticket exists, so /sign/up is not a step back: the only exit
              # ends the sign-up through the existing DELETE cancellation.
              cancel: { label: t("actions.cancel"),
                        action: auth_com_sign_up_check_telephone_otp_path(
                          **sign_up_flow_binding_params,
                          ri: params[:ri],
                        ),
                        method: "delete", },
            }
          end

          def sign_up_telephone_errors
            @visitor_telephone&.errors&.map(&:full_message) || []
          end

          # Mirrors the label `form.submit` looked up, so the button keeps its wording.
          def sign_up_telephone_submit_label
            I18n.t(
              :"helpers.submit.#{VisitorTelephone.model_name.param_key}.create",
              model: VisitorTelephone.model_name.human,
              default: [:"helpers.submit.create", "Create %{model}"],
            )
          end

          def valid_telephone_session?
            return false unless @visitor_telephone.present? && !@visitor_telephone.otp_expired?

            @visitor_telephone.visitor_telephone_status_id == VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP
          end

          def session_public_id_from_registration(registration_session = session[:visitor_telephone_registration])
            if registration_session.is_a?(Hash)
              registration_session["public_id"] || registration_session[:public_id]
            else
              registration_session
            end
          end

          def render_otp_resend_too_soon
            render plain: t("sign.app.registration.email.create.otp_resend_too_soon"), status: :too_many_requests
          end

          def current_registration_telephone
            public_id = session_public_id_from_registration
            return if public_id.blank?

            VisitorTelephone.find_by(public_id: public_id)
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
                entry_method: "telephone",
              ),
            )
          end

          def current_sign_up_flow
            sign_up_flow_locator.current || issue_sign_up_flow!
          end

          def bind_sign_up_flow_to_telephone!(telephone)
            cycle = current_sign_up_flow
            ComTicketRecord.connected_to(role: :writing) do
              cycle.update!(
                principal_id: telephone.visitor_id,
                pending_contact_type: "telephone",
                pending_contact_id: telephone.id,
              )
              SignUpStateMachine.call(ticket: cycle, event: :submit_contact, actor_context: Actor.authn)
            end
            session[:auth_com_up_sequence_id] = cycle.public_id
          end

          def sign_up_flow_locator
            SignUpCycleLocator.new(session, surface: :com, cycle_class: VisitorSignUpFlow)
          end
        end
      end
    end
  end
end
