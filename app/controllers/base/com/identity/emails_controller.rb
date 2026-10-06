# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class EmailsController < ::Base::Com::ApplicationController
        include ::SurfaceInertiaPage
        include ::TurnstilePageProps
        include CloudflareTurnstile
        include ::VerificationVisitor

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        VERIFIED_EMAIL_STATUS_IDS = [
          VisitorEmailStatus::VERIFIED,
          VisitorEmailStatus::VERIFIED_WITH_SIGN_UP,
        ].freeze

        before_action :authorize_emails!, only: :index

        def index
          @client_emails = current_visitor.visitor_emails
          render inertia: true, props: index_page_props
        end

        def edit
          @user_email = current_visitor.visitor_emails.find_by!(public_id: params.expect(:id))
          authorize!(@user_email)
          render inertia: true, props: edit_page_props
        end

        def update
          @user_email = current_visitor.visitor_emails.find_by!(public_id: params.expect(:id))
          authorize!(@user_email)

          unless cloudflare_turnstile_stealth_validation["success"]
            @user_email.errors.add(:base, t("turnstile_error"))
            render_edit_failure
            return
          end

          if @user_email.update(email_preference_params)
            redirect_to(
              edit_base_com_identity_email_path(@user_email.public_id, ri: params[:ri]),
              status: :see_other,
            )
          else
            @user_email.errors.add(:base, t("sign.com.settings.email.update.failure"))
            render_edit_failure
          end
        end

        def destroy
          @user_email = current_visitor.visitor_emails.find_by!(public_id: params.expect(:id))
          authorize!(@user_email)

          if @user_email.undeletable?
            redirect_to(
              base_com_identity_emails_path(ri: params[:ri]),
            )
            return
          end

          unless AuthMethodGuard.can_remove_email?(current_visitor, @user_email)
            redirect_to(
              base_com_identity_emails_path(ri: params[:ri]),
            )
            return
          end

          IdentityCredentialRemovalCommitter.call!(
            actor: current_visitor, credential: @user_email, current_session: current_session, request: request,
          )
          create_audit_event!(ClientChronicleEvent::EMAIL_REMOVED, subject: @user_email)

          redirect_to(
            base_com_identity_emails_path(ri: params[:ri]),
            status: :see_other,
          )
        end

        private

        # Inertia keeps the failed edit on the same 422 the ERB flow answered with, so the existing
        # contract (status and page) is unchanged; the messages travel as props instead of markup.
        def render_edit_failure
          render inertia: "base/com/identity/emails/edit",
                 props: edit_page_props,
                 status: :unprocessable_content
        end

        def index_page_props
          {
            title: "Emails",
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_com_identity_path(ri: params[:ri]),
            },
            new_link: {
              label: t("sign.app.settings.email.index.new_link"),
              href: new_base_com_identity_emails_registration_path(ri: params[:ri]),
            },
            columns: {
              address: t("activerecord.attributes.user_email.address"),
              status: t("activerecord.attributes.user_email.status"),
              actions: "Actions",
            },
            empty_message: t("views.sign.com.settings.emails.index.empty"),
            emails: @client_emails.map { |email| serialize_email_row(email) },
          }
        end

        def serialize_email_row(email)
          verified = VERIFIED_EMAIL_STATUS_IDS.include?(email.visitor_email_status_id)
          {
            public_id: email.public_id,
            address: email.address,
            status_label: verified ? t("views.sign.com.settings.emails.index.verified") :
              t("views.sign.com.settings.emails.index.unverified"),
            edit_link: {
              label: t("sign.app.settings.email.index.edit"),
              href: edit_base_com_identity_email_path(email.public_id, ri: params[:ri]),
            },
          }
        end

        def edit_page_props
          {
            title: t("sign.com.settings.email.edit.title"),
            address: @user_email.address,
            errors: @user_email.errors.full_messages,
            always_on: {
              label: t("sign.com.settings.email.edit.always_on"),
              description: t("sign.com.settings.email.edit.always_on_description"),
            },
            promotional: {
              label: t("sign.com.settings.email.edit.promotional_label"),
              description: t("sign.com.settings.email.edit.promotional_description"),
              checked: @user_email.promotional?,
            },
            notifiable: {
              label: t("sign.com.settings.email.edit.notifiable_label"),
              description: t("sign.com.settings.email.edit.notifiable_description"),
              checked: @user_email.notifiable?,
            },
            form: {
              url: base_com_identity_email_path(@user_email.public_id, ri: params[:ri]),
              scope: "visitor_email",
              submit_label: t("sign.com.settings.email.edit.save"),
            },
            destroy: {
              label: t("sign.app.settings.email.index.delete"),
              url: base_com_identity_email_path(@user_email.public_id, ri: params[:ri]),
              confirm: t("sign.app.settings.email.index.delete_confirm"),
            },
            cancel_link: {
              label: t("sign.app.common.cancel"),
              href: base_com_identity_emails_path(ri: params[:ri]),
            },
            turnstile: turnstile_stealth_props,
          }
        end

        def authorize_emails!
          authorize!(VisitorEmail, to: :index?)
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

        def email_preference_params
          params.fetch(:visitor_email, {}).permit(:promotional, :notifiable)
        end

        def verification_required_action?
          true
        end

        def verification_scope
          "settings_email"
        end
      end
    end
  end
end
