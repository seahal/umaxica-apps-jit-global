# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Settings
      # Passkey registration and management for operators.
      #
      # Org passkeys are the surface's step-up / AAL2 credential (Entra ID
      # covers sign-in SSO only); registration requires step-up bootstrap and
      # the ceremony commits through the passkey ceremony contract.
      class PasskeysController < ::Auth::Org::ApplicationController
        include ::VerificationOperator
        include SignSettingsPasskeyRegistration
        include ::PasskeyRegistrationFlow
        include ::SignRequiresRecoveryPasscodes

        include ::CloudflareTurnstile
        include ::SignAuthorityRedirect
        include ::TurnstilePageProps
        include ::SurfaceInertiaPage

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
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
          @passkeys = current_operator.staff_passkeys
            .where.not(status_id: OperatorPasskeyStatus::REVOKED).order(created_at: :asc)
          render inertia: true, props: passkeys_index_props
        end

        def show
          authorize!(@passkey)
          render inertia: true, props: passkey_show_props
        end

        def new
          authorize!(OperatorPasskey, to: :new?)
          @passkey = current_operator.staff_passkeys.new
          start_passkey_ceremony!(surface: "org", actor: current_operator, session_ref: current_session_public_id)
          render inertia: true, props: passkey_new_props
        end

        def edit
          authorize!(@passkey)
          render inertia: true, props: passkey_edit_props
        end

        # WebAuthn registration is driven by new/options/verification; REST create
        # hands clients to that ceremony without mutating local Sign state.
        def create
          respond_to do |format|
            format.html do
              redirect_to(
                new_auth_org_settings_passkey_path(ri: params[:ri]),
                status: :see_other,
              )
            end
            format.json do
              render json: {
                status: "registration_ceremony_required",
                redirect_path: new_auth_org_settings_passkey_path(ri: params[:ri]),
              }, status: :accepted
            end
          end
        end

        def update
          authorize!(@passkey)

          if @passkey.update(update_params)
            redirect_to(auth_org_settings_passkey_path(@passkey, ri: params[:ri]), status: :see_other)
          else
            render inertia: "auth/org/settings/passkeys/edit",
                   props: passkey_edit_props,
                   status: :unprocessable_content
          end
        end

        def destroy
          authorize!(@passkey)
          unless IdentityCredentialRemovalCommitter.call!(
            actor: current_operator, credential: @passkey, current_session: current_session, request: request,
          )
            redirect_to(
              auth_org_settings_passkeys_path(ri: params[:ri]),
              status: :see_other,
            )
            return
          end
          redirect_to(auth_org_settings_passkeys_path(ri: params[:ri]), status: :see_other)
        end

        private

        def passkeys_index_props
          region = params[:ri]

          {
            title: t("sign.org.settings.passkeys.index.title"),
            description: t("sign.org.settings.passkeys.index.description"),
            add_link: {
              label: t("sign.org.settings.passkeys.index.add"),
              href: new_auth_org_settings_passkey_path(ri: region),
            },
            back_link: { label: t("sign.org.settings.passkeys.index.back"), href: auth_org_settings_path },
            columns: {
              description: t("activerecord.attributes.staff_passkey.description"),
              created_at: t("activerecord.attributes.staff_passkey.created_at"),
              actions: t("actions.actions"),
            },
            empty: t("sign.org.settings.passkeys.index.empty"),
            edit_label: t("actions.edit"),
            destroy_label: t("actions.destroy"),
            destroy_confirm: t("messages.confirm_destroy"),
            turnstile: turnstile_stealth_props,
            passkeys: @passkeys.map do |passkey|
              {
                description: passkey.description,
                created_at: l(passkey.created_at, format: :short),
                edit_href: edit_auth_org_settings_passkey_path(passkey, ri: region),
                destroy_action: auth_org_settings_passkey_path(passkey, ri: region),
              }
            end,
          }
        end

        def passkey_show_props
          region = params[:ri]

          {
            title: t("sign.org.settings.passkeys.show.title"),
            back_link: {
              label: t("sign.org.settings.passkeys.show.back"),
              href: auth_org_settings_passkeys_path(ri: region),
            },
            details: [
              {
                term: t("activerecord.attributes.staff_passkey.description"),
                value: @passkey.description.to_s,
              },
              {
                term: t("activerecord.attributes.staff_passkey.provider_name"),
                value: @passkey.provider_name.presence || t("sign.unknown_authenticator"),
              },
              {
                term: t("activerecord.attributes.staff_passkey.created_at"),
                value: l(@passkey.created_at, format: :long),
              },
              {
                term: t("activerecord.attributes.staff_passkey.sign_count"),
                value: @passkey.sign_count.to_s,
              },
            ],
            edit_link: {
              label: t("actions.edit"),
              href: edit_auth_org_settings_passkey_path(@passkey, ri: region),
            },
            destroy_action: auth_org_settings_passkey_path(@passkey, ri: region),
            destroy_label: t("actions.destroy"),
            destroy_confirm: t("messages.confirm_destroy"),
            turnstile: turnstile_stealth_props,
          }
        end

        def passkey_new_props
          {
            title: t("sign.org.settings.passkeys.new.page_title"),
            description: t("sign.org.settings.passkeys.new.description"),
            registration: {
              options_url: auth_org_settings_passkeys_options_path,
              verification_url: auth_org_settings_passkeys_verification_path,
              turnstile_site_key: turnstile_site_key(:CLOUDFLARE_TURNSTILE_SITE_STEALTH_KEY),
              turnstile_error_message: t("turnstile_error"),
              description_label: t("sign.org.settings.passkeys.new.description_label"),
              description_placeholder: t("sign.org.settings.passkeys.new.description_placeholder"),
              submit_label: t("sign.org.settings.passkeys.new.submit"),
            },
            cancel_link: { label: t("sign.common.cancel"), href: auth_org_settings_passkeys_path },
          }
        end

        def passkey_edit_props
          region = params[:ri]

          {
            title: t("sign.org.settings.passkeys.edit.title"),
            form_action: auth_org_settings_passkey_path(@passkey, ri: region),
            description_label: t("activerecord.attributes.staff_passkey.description"),
            description_value: @passkey.description.to_s,
            submit_label: t("actions.save"),
            cancel_link: {
              label: t("sign.common.cancel"),
              href: auth_org_settings_passkeys_path(ri: region),
            },
            errors_title: t("errors.messages.validation_errors", count: @passkey.errors.count),
            errors: @passkey.errors.full_messages,
            turnstile: turnstile_stealth_props,
          }
        end

        def authorize_passkeys!
          authorize!(OperatorPasskey, to: :index?)
        end

        def authorize_passkey_create!
          authorize!(OperatorPasskey, to: :create?)
        end

        def set_passkey
          @passkey = current_operator.staff_passkeys.find(params.expect(:id))
        end

        def update_params
          key = %i(operator_passkey staff_passkey passkey).find { |candidate| params.key?(candidate) }
          return {} unless key

          params.fetch(key, {}).permit(:description)
        end

        def passkey_registration_actor = current_operator

        def passkey_registration_passkeys = current_operator.staff_passkeys

        def passkey_registration_redirect_url
          auth_org_settings_passkeys_url(ri: params[:ri], host: base_authority_host)
        end

        # Org has no recovery-passcode top-up after registration; render the
        # ceremony result directly.
        def render_verification_success(passkey)
          render json: {
            status: "ok",
            passkey_id: passkey.id,
            redirect_url: bootstrap_return_path(passkey_registration_redirect_url),
          }, status: :created
        end

        def recovery_passcode_requirement_active_strong_credential_count
          0
        end

        def recovery_passcode_requirement_actor = current_operator

        def recovery_passcode_requirement_credential_class = OperatorSecretCredential

        def recovery_passcode_setup_url
          base_org_identity_secrets_url(
            ri: params[:ri],
            host: base_authority_host,
          )
        end
      end
    end
  end
end
