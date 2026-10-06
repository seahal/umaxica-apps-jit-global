# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class TotpsController < BaseController
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        step_up only: :destroy, scope: "settings_totp"

        def index
          authorize!(ClientTotpCredential, to: :index?)
          @totps = current_client.client_totp_credentials
            .where.not(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::DELETED)
            .order(created_at: :asc)
          render inertia: true, props: index_page_props
        end

        def show
          find_totp
          authorize!(@totp)
          render inertia: true, props: show_page_props
        end

        def update
          find_totp
          authorize!(@totp)
          @totp.update!(totp_params)
          redirect_to(base_app_identity_totp_path(@totp.public_id, ri: params[:ri]), status: :see_other)
        rescue ActiveRecord::RecordInvalid, ActionController::ParameterMissing
          render inertia: "base/app/identity/totps/show", props: show_page_props,
                 status: :unprocessable_content
        end

        def destroy
          find_totp
          authorize!(@totp)
          IdentityCredentialRemovalCommitter.call!(
            actor: current_client, credential: @totp, current_session: current_session, request: request,
          )
          redirect_to(base_app_identity_totps_path(ri: params[:ri]), status: :see_other)
        rescue ArgumentError, ActiveRecord::RecordInvalid
          redirect_to(base_app_identity_totp_path(@totp.public_id, ri: params[:ri]), status: :see_other)
        end

        private

        def find_totp
          @totp = current_client.client_totp_credentials.find_by!(public_id: params.expect(:id))
        end

        def totp_params
          params.expect(client_totp_credential: [:title])
        end

        def index_page_props
          {
            title: t("base.identity.totps.title", default: "Authenticator apps"),
            description: t("base.identity.totps.description", default: "Manage your authenticator apps."),
            back_link: { label: t("base.shared.identity.up_link"), href: base_app_identity_path(ri: params[:ri]) },
            new_link: {
              label: t("actions.add", default: "Add authenticator app"),
              href: new_auth_app_settings_totp_path(ri: params[:ri]),
            },
            columns: {
              title: t("activerecord.attributes.user_totp_credential.title"),
              last_otp_at: t("activerecord.attributes.user_totp_credential.last_otp_at"),
              status: t("messages.totp_status_label"),
              actions: t("actions.actions", default: "Actions"),
            },
            empty_message: t("messages.no_totp_found"),
            edit_label: t("actions.edit"),
            totps: @totps.map { |totp| serialize_totp(totp) },
          }
        end

        def serialize_totp(totp)
          {
            public_id: totp.public_id,
            title: totp.title.presence || "-",
            last_otp_at: formatted_last_otp_at(totp),
            status: totp_status_label(totp),
            show_href: base_app_identity_totp_path(totp.public_id, ri: params[:ri]),
          }
        end

        def show_page_props(error: nil)
          {
            title: t("base.identity.totps.show_title", default: "Authenticator app"),
            description: t("base.identity.totps.show_description", default: "Review or rename this authenticator app."),
            back_link: { label: t("actions.back", default: "Back"),
                         href: base_app_identity_totps_path(ri: params[:ri]), },
            totp: {
              public_id: @totp.public_id,
              title: @totp.title,
              last_otp_at: formatted_last_otp_at(@totp),
              status: totp_status_label(@totp),
            },
            form: {
              action: base_app_identity_totp_path(@totp.public_id, ri: params[:ri]),
              title: @totp.title.to_s,
              label: t("activerecord.attributes.user_totp_credential.title"),
              submit_label: t("actions.save"),
            },
            destroy: {
              action: base_app_identity_totp_path(@totp.public_id, ri: params[:ri]),
              label: t("actions.delete"),
              confirm: t("messages.confirm_delete_totp"),
            },
            error: error,
          }
        end

        def totp_status_label(totp)
          keys = {
            ClientTotpCredentialStatus::ACTIVE => "messages.totp_status.active",
            ClientTotpCredentialStatus::INACTIVE => "messages.totp_status.inactive",
            ClientTotpCredentialStatus::REVOKED => "messages.totp_status.revoked",
            ClientTotpCredentialStatus::DELETED => "messages.totp_status.deleted",
            ClientTotpCredentialStatus::NOTHING => "messages.totp_status.nothing",
          }
          t(keys.fetch(totp.user_identity_totp_credential_status_id), default: "Unknown")
        end

        def formatted_last_otp_at(totp)
          value = totp.last_otp_at
          usable = (value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)) && value > Time.zone.at(0)
          usable ? l(value, format: :short) : "-"
        end
      end
    end
  end
end
