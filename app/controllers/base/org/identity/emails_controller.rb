# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class EmailsController < ::Base::Org::ApplicationController
        include CloudflareTurnstile
        include ::VerificationOperator
        include ::SurfaceInertiaPage
        include ::TurnstilePageProps

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authorize_emails!, only: :index

        def index
          @staff_emails = current_operator.staff_emails.order(created_at: :asc)
          render inertia: true, props: index_page_props
        end

        def edit
          @staff_email = current_operator.staff_emails.find_by!(public_id: params.expect(:id))
          authorize!(@staff_email)
          render inertia: true, props: edit_page_props
        end

        def update
          @staff_email = current_operator.staff_emails.find_by!(public_id: params.expect(:id))
          authorize!(@staff_email)

          unless cloudflare_turnstile_stealth_validation["success"]
            @staff_email.errors.add(:base, t("turnstile_error"))
            render_edit_failure
            return
          end

          if @staff_email.update(email_preference_params)
            redirect_to(
              edit_base_org_identity_email_path(@staff_email.public_id, ri: params[:ri]),
              status: :see_other,
            )
          else
            @staff_email.errors.add(:base, t("sign.org.settings.email.update.failure"))
            render_edit_failure
          end
        end

        def destroy
          @staff_email = current_operator.staff_emails.find_by!(public_id: params.expect(:id))
          authorize!(@staff_email)

          if @staff_email.undeletable?
            redirect_to(
              base_org_identity_emails_path(ri: params[:ri]),
            )
            return
          end

          removed = false
          current_operator.with_lock do
            @staff_email = OperatorEmail.lock.find_by!(id: @staff_email.id, staff_id: current_operator.id)
            unless @staff_email.undeletable? || !AuthMethodGuard.can_remove_email?(current_operator, @staff_email)
              @staff_email.destroy!
              removed = true
            end
          end
          redirect_to(
            base_org_identity_emails_path(ri: params[:ri]),
            status: :see_other,
          )
        end

        private

        def render_edit_failure
          render inertia: "base/org/identity/emails/edit",
                 props: edit_page_props,
                 status: :unprocessable_content
        end

        def index_page_props
          {
            title: t("controller.sign.app.setting.index.email"),
            back_link: { label: t("sign.org.settings.show.back"), href: base_org_identity_path },
            new_link: {
              label: t("sign.org.settings.email.index.new_link"),
              href: new_base_org_identity_emails_registration_path,
            },
            columns: {
              value: t("activerecord.attributes.staff_email.address"),
              status: t("activerecord.attributes.staff_email.status"),
              actions: "Actions",
            },
            empty_message: t("sign.org.settings.email.index.empty"),
            entries: @staff_emails.map { |email| serialize_email(email) },
          }
        end

        def serialize_email(email)
          verified = [OperatorEmailStatus::ACTIVE, OperatorEmailStatus::VERIFIED]
            .include?(email.staff_email_status_id)
          status_key = verified ? "verified" : "unverified"

          {
            public_id: email.public_id,
            value: email.address,
            status: page_t("views.sign.org.settings.emails.index.#{status_key}"),
            edit_link: {
              label: t("sign.org.settings.email.index.edit"),
              href: edit_base_org_identity_email_path(email.public_id),
            },
          }
        end

        def edit_page_props
          {
            title: t("sign.org.settings.email.edit.title"),
            address: @staff_email.address,
            form: {
              action: base_org_identity_email_path(@staff_email.public_id, ri: params[:ri]),
              scope: "staff_email",
              promotional: @staff_email.promotional,
              notifiable: @staff_email.notifiable,
              always_on_label: t("sign.org.settings.email.edit.always_on"),
              always_on_description: t("sign.org.settings.email.edit.always_on_description"),
              promotional_label: t("sign.org.settings.email.edit.promotional_label"),
              promotional_description: t("sign.org.settings.email.edit.promotional_description"),
              notifiable_label: t("sign.org.settings.email.edit.notifiable_label"),
              notifiable_description: t("sign.org.settings.email.edit.notifiable_description"),
              submit: t("sign.org.settings.email.edit.save"),
              turnstile: turnstile_stealth_props,
            },
            delete: {
              label: t("sign.org.settings.email.index.delete"),
              href: base_org_identity_email_path(@staff_email.public_id),
              confirm: t("sign.org.settings.email.index.delete_confirm"),
            },
            cancel_link: { label: t("sign.common.cancel"), href: base_org_identity_emails_path },
            error_messages: @staff_email.errors.full_messages,
          }
        end

        def authorize_emails!
          authorize!(OperatorEmail, to: :index?)
        end

        def email_preference_params
          params.fetch(:staff_email, {}).permit(:promotional, :notifiable)
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
