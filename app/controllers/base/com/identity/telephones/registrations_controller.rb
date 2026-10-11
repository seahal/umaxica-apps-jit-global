# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      module Telephones
        class RegistrationsController < ::Base::Com::ApplicationController
          include ::SurfaceInertiaPage
          include ::TurnstilePageProps
          include CloudflareTurnstile

          include CommonOtp
          include SignSettingsTelephoneRegistration

          include EnforcementIdentifierGate

          include ::VerificationVisitor

          AUTHENTICATION_MODE = :private

          TELEPHONE_VERIFICATION_RATE_LIMIT = 5
          TELEPHONE_VERIFICATION_RATE_WINDOW = 60
          before_action :authenticate_visitor!
          # Object-level authorization (ActionPolicy): registering a telephone is a fresh-record action
          # for the authenticated visitor, so gate by actor type. Each step builds/looks up the record
          # for current_visitor. Verification/turnstile/rate-limit guards remain on the flow.
          before_action :authorize_telephone_registration!, only: %i(new create edit update)

          def new
            @user_telephone = VisitorTelephone.new
            reset_registration_session!
            render inertia: true, props: new_page_props
          end

          def edit
            @user_telephone = current_registration_telephone
            return render inertia: true, props: edit_page_props if valid_registration_session?

            reset_registration_session!
            redirect_to(
              new_base_com_identity_telephones_registration_path(ri: params[:ri]),
            )
          end

          def create
            visitor = current_visitor
            return head :unauthorized if visitor.blank?

            unless cloudflare_turnstile_stealth_validation["success"]
              @user_telephone = VisitorTelephone.new
              @user_telephone.errors.add(:base, t("turnstile_error"))
              render_registration_new_failure
              return
            end

            tel_params = params(user_telephone: [:raw_number, :number])
            number = tel_params[:raw_number] || tel_params[:number]

            # adr/unified-enforcement.md, Identifier attachment enforcement: an in-force
            # Identifier Effect with attachment_blocked rejects attaching this identifier to
            # an existing account, at the same enumeration-resistance discipline as the
            # ordinary validation failure.
            if number.present? && enforcement_blocks_telephone_attachment?(
              effect_class: ComEnforcementIdentifierEffect, realm: "com", telephone: number,
            )
              @user_telephone = VisitorTelephone.new
              @user_telephone.errors.add(:raw_number, :blank)
              render_registration_new_failure
              return
            end

            unless initiate_visitor_telephone_verification(visitor, number, auto_accept_confirmations: true)
              render_registration_new_failure
              return
            end

            session[registration_session_key] = @user_telephone.id
            start_telephone_ceremony!(
              surface: "com",
              actor: current_visitor,
              session_ref: current_session_public_id,
              candidate: @user_telephone,
            )
            redirect_to(
              edit_base_com_identity_telephones_registration_path(ri: params[:ri]),
            )
          end

          def update
            @user_telephone = current_registration_telephone

            unless valid_registration_session?
              reset_registration_session!
              redirect_to(
                new_base_com_identity_telephones_registration_path(ri: params[:ri]),
              )
              return
            end

            unless cloudflare_turnstile_stealth_validation["success"]
              @user_telephone.errors.add(:base, t("turnstile_error"))
              render_registration_edit_failure
              return
            end

            submitted_code = params.dig(:user_telephone, :pass_code)
            if submitted_code.blank?
              @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.code_required"))
              render_registration_edit_failure
              return
            end

            status = complete_visitor_telephone_verification(@user_telephone.id, submitted_code)

            handle_registration_update_status(status)
          end

          private

          # The failure paths keep the page and the 422 the ERB flow answered with.
          def render_registration_new_failure
            render inertia: "base/com/identity/telephones/registrations/new",
                   props: new_page_props,
                   status: :unprocessable_content
          end

          def render_registration_edit_failure
            render inertia: "base/com/identity/telephones/registrations/edit",
                   props: edit_page_props,
                   status: :unprocessable_content
          end

          def new_page_props
            {
              title: t("sign.app.settings.telephone.new.title"),
              description: t("views.sign.com.settings.telephones.registrations.new.description"),
              errors: @user_telephone.errors.map(&:full_message),
              form: {
                url: base_com_identity_telephones_registration_path(ri: params[:ri]),
                method: "post",
                scope: "visitor_telephone",
                submit_label: t("actions.submit"),
              },
              number_label: VisitorTelephone.human_attribute_name(:number),
              number_placeholder: "+819012345678",
              help_text: t("views.sign.com.settings.telephones.registrations.new.help_text"),
              cancel_link: {
                label: t("actions.cancel"),
                href: base_com_identity_telephones_path(ri: params[:ri]),
              },
              turnstile: turnstile_stealth_props,
            }
          end

          def edit_page_props
            {
              title: t("sign.app.registration.telephone.edit.page_title"),
              description: t("sign.app.registration.telephone.create.verification_code_sent"),
              errors: @user_telephone.errors.map(&:full_message),
              form: {
                url: base_com_identity_telephones_registration_path(ri: params[:ri]),
                method: "patch",
                # The ERB form was `form_with model: @user_telephone`, so the wire scope is the
                # model name. Keeping it identical keeps the request shape unchanged.
                scope: "visitor_telephone",
                submit_label: t("sign.app.registration.telephone.edit.submit"),
              },
              code_label: t("sign.app.registration.telephone.edit.code_label"),
              code_placeholder: t("sign.app.registration.telephone.edit.code_placeholder"),
              delivery_help: t("sign.app.registration.telephone.edit.delivery_help"),
              cancel_link: {
                label: t("actions.cancel"),
                href: base_com_identity_telephones_path(ri: params[:ri]),
              },
              turnstile: turnstile_stealth_props,
            }
          end

          def authorize_telephone_registration!
            authorize!(VisitorTelephone, to: :create?)
          end

          def handle_registration_update_status(status)
            case status
            when :success
              finish_telephone_ceremony!(
                surface: "com",
                actor: current_visitor,
                session_ref: current_session_public_id,
                candidate: @user_telephone,
              )
              reset_registration_session!
              redirect_to(
                base_com_identity_telephones_url(
                  ri: params[:ri],
                  host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
                ),
                allow_other_host: cross_host_redirect_allowed?,
              )
            when :session_expired, :locked
              reset_registration_session!
              redirect_to(
                new_base_com_identity_telephones_registration_path(ri: params[:ri]),
              )
            else
              render_registration_edit_failure
            end
          end

          def current_registration_telephone
            VisitorTelephone.find_by(id: session[registration_session_key])
          end

          def valid_registration_session?
            @user_telephone.present? &&
              @user_telephone.visitor_id == current_visitor.id &&
              !@user_telephone.otp_expired? &&
              @user_telephone.visitor_telephone_status_id == VisitorTelephoneStatus::UNVERIFIED
          end

          def registration_session_key
            :settings_telephone_registration_id
          end

          def reset_registration_session!
            session.delete(registration_session_key)
            reset_telephone_ceremony_session!
          end

          def verification_required_action?
            current_visitor&.verified_telephone?
          end

          def verification_scope
            "settings_telephone"
          end

          def initiate_visitor_telephone_verification(visitor, number, auto_accept_confirmations: false)
            return false if visitor.blank?

            check_telephone_verification_rate_limit!

            digest = IdentifierBlindIndex.bidx_for_telephone(number)
            existing_visitor_telephone =
              digest.present? ? visitor.visitor_telephones.find_by(number_digest: digest) : nil

            @user_telephone = existing_visitor_telephone || visitor.visitor_telephones.build(raw_number: number)
            @user_telephone.raw_number = number if existing_visitor_telephone
            @user_telephone.visitor_telephone_status_id = VisitorTelephoneStatus::UNVERIFIED
            if auto_accept_confirmations
              @user_telephone.confirm_policy = true
              @user_telephone.confirm_using_mfa = true
            end

            if digest.present? && existing_visitor_telephone.blank?
              VisitorTelephone.where(
                number_digest: digest,
                visitor_id: visitor.id,
                visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
              ).destroy_all
            end

            otp_number = generate_otp_attributes(@user_telephone)
            return false unless @user_telephone.valid?

            @user_telephone.save!
            send_telephone_verification_sms(@user_telephone, otp_number)
            true
          end

          def complete_visitor_telephone_verification(id, submitted_code)
            @user_telephone = VisitorTelephone.find_by(id: id)
            if @user_telephone.blank? ||
                @user_telephone.otp_expired? ||
                @user_telephone.visitor_telephone_status_id != VisitorTelephoneStatus::UNVERIFIED
              return :session_expired
            end

            result = verify_otp_code_and_consume(@user_telephone, submitted_code)

            unless result[:success]
              if @user_telephone.locked?
                @user_telephone.destroy!
                return :locked
              end

              @user_telephone.errors.add(:pass_code, t("sign.app.registration.telephone.update.invalid_code"))
              return :invalid_code
            end

            # sign/id verifies the OTP and commits the settings telephone.
            :success
          end

          def send_telephone_verification_sms(visitor_telephone, otp_number)
            OtpAdapter.for(surface: :com, channel: :telephone).deliver(
              record: visitor_telephone,
              otp_code: otp_number,
              message_style: :localized_verification,
            )
          end

          def check_telephone_verification_rate_limit!
            cache_key = "rate-limit:telephone_verification:#{request.remote_ip}"
            count = Rails.configuration.x.rate_limit.fetch(:store).increment(
              cache_key,
              1,
              expires_in: TELEPHONE_VERIFICATION_RATE_WINDOW.seconds,
            )
            return unless count && count > TELEPHONE_VERIFICATION_RATE_LIMIT

            Rails.logger.info(
              JitLogEvent.format(
                "telephone.verification.rate_limited",
                ip: request.remote_ip,
                retry_after: TELEPHONE_VERIFICATION_RATE_WINDOW,
              ),
            )
            raise ActionController::TooManyRequests
          end
        end
      end
    end
  end
end
