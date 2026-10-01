# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      module Telephones
        class RegistrationsController < ::Base::Org::ApplicationController
          include CloudflareTurnstile

          include SignOperatorTelephoneRegistrable
          include SignSettingsTelephoneRegistration

          include EnforcementIdentifierGate

          include ::VerificationOperator

          include ::SurfaceInertiaPage
          include ::TurnstilePageProps

          AUTHENTICATION_MODE = :private

          before_action :authenticate_operator!
          # Object-level authorization (ActionPolicy): registering a telephone is a fresh-record action
          # for the authenticated operator, so gate by actor type. Each step builds/looks up the record
          # for current_operator. Verification/turnstile guards remain on the flow.
          before_action :authorize_telephone_registration!, only: %i(new create edit update)

          def new
            @staff_telephone = OperatorTelephone.new
            reset_registration_session!
            render inertia: true, props: new_page_props
          end

          def edit
            @staff_telephone = current_registration_telephone
            return render(inertia: true, props: edit_page_props) if valid_registration_session?

            reset_registration_session!
            redirect_to(
              new_base_org_identity_telephones_registration_path,
            )
          end

          def create
            unless cloudflare_turnstile_stealth_validation["success"]
              @staff_telephone = OperatorTelephone.new
              @staff_telephone.errors.add(:base, t("turnstile_error"))
              render_new_failure
              return
            end

            tel_params = params(staff_telephone: [:raw_number, :number])
            number = tel_params[:raw_number] || tel_params[:number]

            # adr/unified-enforcement.md, Identifier attachment enforcement: an in-force
            # Identifier Effect with attachment_blocked rejects attaching this identifier to
            # an existing account, at the same enumeration-resistance discipline as the
            # ordinary validation failure.
            if number.present? && enforcement_blocks_telephone_attachment?(
              effect_class: OrgEnforcementIdentifierEffect, realm: "org", telephone: number,
            )
              @staff_telephone = OperatorTelephone.new
              @staff_telephone.errors.add(:raw_number, :blank)
              render_new_failure
              return
            end

            unless initiate_staff_telephone_verification(current_operator, number)
              render_new_failure
              return
            end

            session[registration_session_key] = @staff_telephone.id
            start_telephone_ceremony!(
              surface: "org",
              actor: current_operator,
              session_ref: current_session_public_id,
              candidate: @staff_telephone,
            )
            redirect_to(
              edit_base_org_identity_telephones_registration_path,
            )
          end

          def update
            @staff_telephone = current_registration_telephone
            unless valid_registration_session?
              reset_registration_session!
              redirect_to(
                new_base_org_identity_telephones_registration_path,
              )
              return
            end

            unless cloudflare_turnstile_stealth_validation["success"]
              @staff_telephone.errors.add(:base, t("turnstile_error"))
              render_edit_failure
              return
            end

            submitted_code = params.dig(:staff_telephone, :pass_code)
            if submitted_code.blank?
              @staff_telephone.errors.add(:pass_code, t("sign.org.registration.telephone.update.code_required"))
              render_edit_failure
              return
            end

            result = complete_staff_telephone_verification(@staff_telephone.id, submitted_code)

            handle_registration_update_result(result)
          end

          private

          def render_new_failure
            render inertia: "base/org/identity/telephones/registrations/new",
                   props: new_page_props,
                   status: :unprocessable_content
          end

          def render_edit_failure
            render inertia: "base/org/identity/telephones/registrations/edit",
                   props: edit_page_props,
                   status: :unprocessable_content
          end

          def new_page_props
            {
              title: t("sign.org.settings.telephone.new.title"),
              form: {
                action: base_org_identity_telephones_registration_path,
                scope: "staff_telephone",
                number_label: t("activerecord.attributes.staff_telephone.number"),
                number_placeholder: "+819012345678",
                submit: t("actions.submit"),
                turnstile: turnstile_stealth_props,
              },
              cancel_link: {
                label: t("actions.cancel"),
                href: base_org_identity_telephones_path(ri: params[:ri]),
              },
              error_messages: @staff_telephone.errors.full_messages,
            }
          end

          def edit_page_props
            {
              title: t("sign.app.registration.telephone.edit.page_title"),
              description: t("sign.app.registration.telephone.create.verification_code_sent"),
              delivery_help: t("sign.app.registration.telephone.edit.delivery_help"),
              form: {
                action: base_org_identity_telephones_registration_path,
                scope: "staff_telephone",
                code_label: t("sign.app.registration.telephone.edit.code_label"),
                code_placeholder: t("sign.app.registration.telephone.edit.code_placeholder"),
                submit: t("sign.app.registration.telephone.edit.submit"),
                turnstile: turnstile_stealth_props,
              },
              cancel_link: {
                label: t("actions.cancel"),
                href: base_org_identity_telephones_path(ri: params[:ri]),
              },
              error_messages: @staff_telephone.errors.full_messages,
            }
          end

          def authorize_telephone_registration!
            authorize!(OperatorTelephone, to: :create?)
          end

          def handle_registration_update_result(result)
            case result
            when :success
              finish_telephone_ceremony!(
                surface: "org",
                actor: current_operator,
                session_ref: current_session_public_id,
                candidate: @staff_telephone,
              )
              reset_registration_session!
              redirect_to_surface_url(
                base_org_identity_telephones_url(
                  ri: params[:ri],
                  host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
                ),
              )
            when :session_expired, :locked
              reset_registration_session!
              redirect_to(
                new_base_org_identity_telephones_registration_path,
              )
            else
              render_edit_failure
            end
          end

          def current_registration_telephone
            current_operator.staff_telephones.find_by(id: session[registration_session_key])
          end

          def valid_registration_session?
            @staff_telephone.present? &&
              !@staff_telephone.otp_expired? &&
              @staff_telephone.staff_telephone_status_id == OperatorTelephoneStatus::UNVERIFIED
          end

          def registration_session_key
            :staff_telephone_registration_id
          end

          def reset_registration_session!
            session.delete(registration_session_key)
            reset_telephone_ceremony_session!
          end

          def verification_required_action?
            true
          end

          def verification_scope
            "settings_telephone"
          end
        end
      end
    end
  end
end
