# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class TelephonesController < ::Base::Com::ApplicationController
        include ::SurfaceInertiaPage
        include CommonOtp
        include ::SignSettingsAuthorityRedirect

        include ::VerificationVisitor

        AUTHENTICATION_MODE = :private

        TELEPHONE_VERIFICATION_RATE_LIMIT = 5
        TELEPHONE_VERIFICATION_RATE_WINDOW = 60
        VERIFIED_TELEPHONE_STATUS_IDS = [
          VisitorTelephoneStatus::VERIFIED,
          VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP,
        ].freeze

        # Object-level authorization (ActionPolicy): new/create gate the actor type; edit
        # authorize the owned record (find_by! is owner-scoped, so a non-owner gets 404 first).
        # Verification/rate-limit guards remain in place.
        before_action :authorize_telephone_registration!, only: %i(new create)

        def index
          authorize!(VisitorTelephone, to: :index?)
          @client_telephones = current_visitor.visitor_telephones.order(created_at: :asc)
          render inertia: true, props: index_page_props
        end

        def new
          @user_telephone = VisitorTelephone.new
        end

        def edit
          @user_telephone = current_visitor.visitor_telephones.find_by!(public_id: params.expect(:id))
          authorize!(@user_telephone)
          render inertia: true, props: edit_page_props
        end

        def create
          visitor = current_visitor
          return head :unauthorized if visitor.blank?

          tel_params = params.slice(:user_telephone).permit(user_telephone: [:raw_number, :number]).fetch(
            :user_telephone, {},
          )
          number = tel_params[:raw_number] || tel_params[:number]
          if initiate_visitor_telephone_verification(visitor, number, auto_accept_confirmations: true)
            redirect_to(edit_base_com_identity_telephones_registration_path(ri: params[:ri]))
          else
            render :new, status: :unprocessable_content
          end
        end

        def destroy
          telephone = current_visitor.visitor_telephones.find_by!(public_id: params.expect(:id))
          authorize!(telephone)

          unless AuthMethodGuard.can_remove_telephone?(current_visitor, telephone)
            redirect_to(
              base_com_identity_telephones_path(ri: params[:ri]),
            )
            return
          end

          IdentityCredentialRemovalCommitter.call!(
            actor: current_visitor, credential: telephone, current_session: current_session, request: request,
          )
          create_audit_event!(ClientChronicleEvent::TELEPHONE_REMOVED, subject: telephone)

          redirect_to(
            base_com_identity_telephones_path(ri: params[:ri]),
            status: :see_other,
          )
        end

        private

        def index_page_props
          {
            title: "Telephones",
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_com_identity_path(ri: params[:ri]),
            },
            new_link: {
              label: t("sign.app.settings.telephone.index.new_link"),
              href: new_base_com_identity_telephones_registration_path(ri: params[:ri]),
            },
            columns: {
              number: VisitorTelephone.human_attribute_name(:number),
              status: t("activerecord.attributes.user_telephone.status"),
              actions: t("views.sign.com.settings.telephones.index.actions"),
            },
            empty_message: t("views.sign.com.settings.telephones.index.empty"),
            telephones: @client_telephones.map { |telephone| serialize_telephone_row(telephone) },
          }
        end

        def serialize_telephone_row(telephone)
          verified = VERIFIED_TELEPHONE_STATUS_IDS.include?(telephone.visitor_telephone_status_id)
          {
            public_id: telephone.public_id,
            number: telephone.number,
            status_label: if verified
                            t("views.sign.com.settings.telephones.index.verified")
                          else
                            t("views.sign.com.settings.telephones.index.unverified")
                          end,
            edit_link: {
              label: t("sign.app.settings.telephone.index.edit"),
              href: edit_base_com_identity_telephone_path(telephone.public_id, ri: params[:ri]),
            },
          }
        end

        def edit_page_props
          {
            title: t("sign.app.settings.telephone.edit.title"),
            number: @user_telephone.number,
            destroy: {
              label: t("sign.app.settings.telephone.index.delete"),
              url: base_com_identity_telephone_path(@user_telephone.public_id, ri: params[:ri]),
              confirm: t("sign.app.settings.telephone.index.delete_confirm"),
            },
            cancel_link: {
              label: t("sign.app.common.cancel"),
              href: base_com_identity_telephones_path(ri: params[:ri]),
            },
          }
        end

        def authorize_telephone_registration!
          authorize!(VisitorTelephone, to: :create?)
        end

        def verification_required_action?
          true
        end

        def create_audit_event!(event_id, subject:)
          ChronicleRecord.connected_to(role: :writing) do
            ClientChronicleEvent.find_or_create_by!(id: event_id)
            ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
          end

          ClientChronicle.create!(
            actor_type: "Visitor",
            actor_id: current_visitor.id,
            event_id: event_id,
            subject_id: subject.id.to_s,
            subject_type: subject.class.name,
            occurred_at: Time.current,
          )
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
