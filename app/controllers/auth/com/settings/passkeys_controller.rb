# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Settings
      # Passkey registration and management for visitors.
      class PasskeysController < ::Auth::Com::ApplicationController
        include ::VerificationVisitor
        include SignSettingsPasskeyRegistration
        include ::PasskeyRegistrationFlow
        include ::SignRequiresRecoveryPasscodes

        include ::CloudflareTurnstile
        include ::SurfaceInertiaPage
        include ::TurnstilePageProps

        AUTHENTICATION_MODE = :private

        before_action :authenticate_visitor!
        # Object-level authorization (ActionPolicy): index/create gate the actor type; show/edit/
        # update/destroy authorize the owned record (set_passkey is owner-scoped -> 404 first).
        # Step-up / Turnstile / WebAuthn-challenge guards remain in place for the registration ceremony.
        before_action :authorize_passkeys!, only: %i(index)
        before_action :authorize_passkey_create!, only: %i(create)
        step_up only: %i(new create), bootstrap: true
        step_up only: :destroy
        before_action :require_recovery_passcodes_for_mfa_registration!, only: %i(new create)
        before_action :set_passkey, only: %i(show edit update destroy)

        def index
          @passkeys = current_visitor.visitor_passkeys.where.not(
            status_id: [VisitorPasskeyStatus::REVOKED, VisitorPasskeyStatus::DELETED],
          ).order(created_at: :asc)
          render inertia: true, props: passkey_index_props
        end

        def show
          authorize!(@passkey)
          render inertia: true, props: passkey_show_props
        end

        def new
          authorize!(VisitorPasskey, to: :new?)
          @passkey = current_visitor.visitor_passkeys.new
          start_passkey_ceremony!(surface: "com", actor: current_visitor, session_ref: current_session_public_id)
          render inertia: true, props: passkey_new_props
        end

        def edit
          authorize!(@passkey)
          render inertia: true, props: passkey_edit_props
        end

        def create
          respond_to do |format|
            format.html do
              redirect_to(
                new_auth_com_settings_passkey_path(ri: params[:ri]),
                status: :see_other,
              )
            end
            format.json do
              render json: {
                status: "registration_ceremony_required",
                redirect_path: new_auth_com_settings_passkey_path(ri: params[:ri]),
              }, status: :accepted
            end
          end
        end

        def update
          authorize!(@passkey)

          if @passkey.update(update_params)
            redirect_to(auth_com_settings_passkey_path(@passkey.public_id, ri: params[:ri]), status: :see_other)
          else
            # The Inertia contract carries a validation failure as a redirect back with the errors
            # hash; the guards that reached this point are unchanged.
            redirect_to(
              edit_auth_com_settings_passkey_path(@passkey.public_id, ri: params[:ri]),
              status: :see_other,
              inertia: { errors: @passkey.errors.to_hash(true).transform_values(&:first) },
            )
          end
        end

        def destroy
          authorize!(@passkey)
          unless IdentityCredentialRemovalCommitter.call!(
            actor: current_visitor, credential: @passkey, current_session: current_session, request: request,
          )
            redirect_to(
              auth_com_settings_passkeys_path(ri: params[:ri]),
              status: :see_other,
            )
            return
          end
          redirect_to(auth_com_settings_passkeys_path(ri: params[:ri]), status: :see_other)
        end

        private

        def passkey_index_props
          {
            title: t("sign.org.settings.passkeys.index.title"),
            add_link: { label: t("sign.org.settings.passkeys.index.add"),
                        href: new_auth_com_settings_passkey_path(ri: params[:ri]), },
            back_link: { label: t("sign.org.settings.passkeys.index.back"),
                         href: auth_com_settings_path(ri: params[:ri]), },
            columns: {
              description: t("activerecord.attributes.staff_passkey.description"),
              created_at: t("activerecord.attributes.staff_passkey.created_at"),
              actions: t("actions.actions"),
            },
            passkeys: @passkeys.map { |passkey| serialize_passkey_row(passkey) },
            empty_message: t("sign.org.settings.passkeys.index.empty"),
            edit_label: t("actions.edit"),
            destroy_label: t("actions.destroy"),
            confirm_message: t("messages.confirm_destroy"),
            turnstile: turnstile_stealth_props,
          }
        end

        def serialize_passkey_row(passkey)
          {
            public_id: passkey.public_id,
            description: passkey.description,
            created_at: I18n.l(passkey.created_at, format: :short),
            edit_href: edit_auth_com_settings_passkey_path(passkey.public_id, ri: params[:ri]),
            destroy_href: auth_com_settings_passkey_path(passkey.public_id, ri: params[:ri]),
          }
        end

        def passkey_show_props
          {
            title: t("sign.org.settings.passkeys.show.title"),
            back_link: { label: t("sign.org.settings.passkeys.show.back"),
                         href: auth_com_settings_passkeys_path(ri: params[:ri]), },
            details: [
              { key: "description",
                label: t("activerecord.attributes.staff_passkey.description"),
                value: @passkey.description.to_s, },
              {
                key: "provider_name",
                label: t("activerecord.attributes.staff_passkey.provider_name"),
                value: @passkey.provider_name.presence || t("sign.unknown_authenticator"),
              },
              {
                key: "created_at",
                label: t("activerecord.attributes.staff_passkey.created_at"),
                value: I18n.l(@passkey.created_at, format: :long),
              },
              { key: "sign_count",
                label: t("activerecord.attributes.staff_passkey.sign_count"),
                value: @passkey.sign_count.to_s, },
            ],
            edit_link: {
              label: t("actions.edit"),
              href: edit_auth_com_settings_passkey_path(@passkey.public_id, ri: params[:ri]),
            },
            destroy_href: auth_com_settings_passkey_path(@passkey.public_id, ri: params[:ri]),
            destroy_label: t("actions.destroy"),
            confirm_message: t("messages.confirm_destroy"),
            turnstile: turnstile_stealth_props,
          }
        end

        def passkey_edit_props
          {
            title: t("sign.org.settings.passkeys.edit.title"),
            action: auth_com_settings_passkey_path(@passkey.public_id, ri: params[:ri]),
            field_label: t("activerecord.attributes.staff_passkey.description"),
            description: @passkey.description.to_s,
            submit_label: t("actions.save"),
            cancel_link: { label: t("sign.common.cancel"), href: auth_com_settings_passkeys_path(ri: params[:ri]) },
            turnstile: turnstile_stealth_props,
          }
        end

        def passkey_new_props
          {
            title: t("sign.org.settings.passkeys.new.page_title"),
            description: t("sign.org.settings.passkeys.new.description"),
            panel: {
              options_url: auth_com_settings_passkeys_options_path(ri: params[:ri]),
              verification_url: auth_com_settings_passkeys_verification_path(ri: params[:ri]),
              turnstile_site_key: turnstile_stealth_props.fetch(:site_key),
              turnstile_error_message: t("turnstile_error"),
              description_label: t("sign.org.settings.passkeys.new.description_label"),
              description_placeholder: t("sign.org.settings.passkeys.new.description_placeholder"),
              submit_label: t("sign.org.settings.passkeys.new.submit"),
            },
            cancel_link: { label: t("sign.common.cancel"), href: auth_com_settings_passkeys_path(ri: params[:ri]) },
          }
        end

        def authorize_passkeys!
          authorize!(VisitorPasskey, to: :index?)
        end

        def authorize_passkey_create!
          authorize!(VisitorPasskey, to: :create?)
        end

        def set_passkey
          @passkey = current_visitor.visitor_passkeys.find_by!(public_id: params.expect(:id))
        end

        def update_params
          key = params.key?(:visitor_passkey) ? :visitor_passkey : :passkey
          params.fetch(key, {}).permit(:description)
        end

        def passkey_registration_actor = current_visitor

        def passkey_registration_passkeys = current_visitor.visitor_passkeys

        def passkey_registration_redirect_url
          auth_com_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL"))
        end

        def recovery_passcode_requirement_active_strong_credential_count
          current_visitor.visitor_passkeys.active.count
        end

        def recovery_passcode_requirement_actor = current_visitor

        def recovery_passcode_requirement_credential_class = VisitorSecretCredential

        def recovery_passcode_setup_url
          base_com_identity_url(
            ri: params[:ri],
            host: base_authority_host,
          )
        end

        def recovery_passcode_top_up_actor = current_visitor

        def recovery_passcode_top_up_credential_class = VisitorSecretCredential

        def recovery_passcode_reveal_redirect_url(token)
          base_com_identity_url(
            ri: params[:ri],
            token: token,
            host: base_authority_host,
          )
        end
      end
    end
  end
end
