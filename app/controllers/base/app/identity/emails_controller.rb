# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class EmailsController < BaseController
        include ::SurfaceInertiaPage
        include CloudflareTurnstile
        include VerificationClient

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :authorize_emails!, only: :index
        # The edit page carries the delete action, so it is gated with it; this matches com,
        # which requires settings_email step-up for the whole controller.
        step_up only: %i(edit update destroy), scope: "settings_email"

        def index
          render inertia: true, props: emails_index_props(current_client.client_emails)
        end

        def edit
          @user_email = current_client.client_emails.find_by!(public_id: params.expect(:id))
          authorize!(@user_email)
          render inertia: true, props: email_edit_props(@user_email)
        end

        def update
          @user_email = current_client.client_emails.find_by!(public_id: params.expect(:id))
          authorize!(@user_email)
          unless cloudflare_turnstile_stealth_validation["success"]
            return render(
              inertia: "base/app/identity/emails/edit",
              props: email_edit_props(@user_email, error: t("turnstile_error")),
              status: :unprocessable_content,
            )
          end
          if @user_email.update(email_preference_params)
            redirect_to(edit_base_app_identity_email_path(@user_email.public_id, ri: params[:ri]), status: :see_other)
          else
            render(
              inertia: "base/app/identity/emails/edit",
              props: email_edit_props(@user_email, error: t("sign.app.settings.email.update.failure")),
              status: :unprocessable_content,
            )
          end
        end

        def destroy
          @user_email = current_client.client_emails.find_by!(public_id: params.expect(:id))
          authorize!(@user_email)
          if @user_email.undeletable? || (verified_email?(@user_email) && !AuthMethodGuard.can_remove_email?(
            current_client, @user_email,
          ))
            return redirect_to(base_app_identity_emails_path(ri: params[:ri]), status: :see_other)
          end

          @user_email.destroy!
          create_audit_event!(ClientChronicleEvent::EMAIL_REMOVED, subject: @user_email)
          redirect_to(base_app_identity_emails_path(ri: params[:ri]), status: :see_other)
        end

        private

        def authorize_emails! = authorize!(ClientEmail, to: :index?)

        def verified_email?(email) = AuthMethodGuard::VERIFIED_EMAIL_STATUSES.include?(email.user_email_status_id)

        def emails_index_props(emails)
          {
            title: "Emails",
            empty_message: t("views.sign.app.settings.emails.index.empty"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_app_identity_path(ri: params[:ri]),
            },
            new_link: {
              label: t("sign.app.settings.email.index.new_link"),
              href: new_base_app_identity_emails_registration_path(ri: params[:ri]),
            },
            table_headings: {
              address: t("activerecord.attributes.user_email.address"),
              status: "Status",
              actions: "Actions",
            },
            emails: emails.map { |email| serialize_email(email) },
          }
        end

        def serialize_email(email)
          {
            public_id: email.public_id,
            address: email.address,
            status_label: verified_status?(email) ?
              t("views.sign.app.settings.emails.index.verified") : t("views.sign.app.settings.emails.index.unverified"),
            edit_link: {
              label: t("sign.app.settings.email.index.edit"),
              href: edit_base_app_identity_email_path(email.public_id, ri: params[:ri]),
            },
          }
        end

        def verified_status?(email)
          [ClientEmailStatus::VERIFIED, ClientEmailStatus::VERIFIED_WITH_SIGN_UP].include?(email.user_email_status_id)
        end

        def email_edit_props(email, error: nil)
          {
            title: t("sign.app.settings.email.edit.title"),
            address: email.address,
            form: {
              action: base_app_identity_email_path(email.public_id, ri: params[:ri]),
              submit_label: t("sign.app.settings.email.edit.save"),
              locked: email.subscription_preferences_locked?,
              always_on_label: t("sign.app.settings.email.edit.always_on"),
              always_on_description: t("sign.app.settings.email.edit.always_on_description"),
              promotional: {
                checked: email.promotional?,
                label: t("sign.app.settings.email.edit.promotional_label"),
                description: t("sign.app.settings.email.edit.promotional_description"),
              },
              notifiable: {
                checked: email.notifiable?,
                label: t("sign.app.settings.email.edit.notifiable_label"),
                description: t("sign.app.settings.email.edit.notifiable_description"),
              },
            },
            delete: {
              label: t("sign.app.settings.email.index.delete"),
              confirm: t("sign.app.settings.email.index.delete_confirm"),
              url: base_app_identity_email_path(email.public_id, ri: params[:ri]),
            },
            cancel_link: { label: "Cancel", href: base_app_identity_emails_path },
            error: error,
          }
        end

        def email_preference_params
          permitted_params = params.fetch(:user_email, {}).permit(:promotional, :notifiable)
          return permitted_params unless @user_email.subscription_preferences_locked?

          permitted_params.to_h.symbolize_keys.merge(
            promotional: @user_email.promotional,
            notifiable: @user_email.notifiable,
          )
        end

        def create_audit_event!(event_id, subject:)
          ClientChronicle.create!(
            actor_type: "Client", actor_id: current_client.id, event_id: event_id,
            subject_id: subject.id.to_s, subject_type: subject.class.name, occurred_at: Time.current,
          )
        end
      end
    end
  end
end
