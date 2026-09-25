# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Settings
      # Passkey registration and management for users.
      #
      # Registration Flow:
      # 1. User visits /settings/passkeys/new
      # 2. POST /settings/passkeys/options to get WebAuthn challenge
      # 3. Browser performs navigator.credentials.create()
      # 4. POST /settings/passkeys/verification with credential + challenge_id
      # 5. sign/id verifies the ceremony and commits the passkey binding
      class PasskeysController < ::Auth::App::ApplicationController
        include ::SurfaceInertiaPage
        include ::TurnstilePageProps
        include ::VerificationClient
        include SignSettingsPasskeyRegistration
        include ::PasskeyRegistrationFlow
        include ::SignAuthorityRedirect

        include ::CloudflareTurnstile

        AUTHENTICATION_MODE = :private
        layout :settings_passkeys_layout

        before_action :authenticate_client!
        step_up only: %i(new create), bootstrap: true
        step_up only: :destroy

        # GET /settings/passkeys
        def index
          authorize!(ClientPasskey, to: :index?)
          @passkeys = current_client.client_passkeys.order(created_at: :asc)
          render_inertia_page(props: index_page_props)
        end

        # GET /settings/passkeys/:id
        def show
          set_passkey
          authorize!(@passkey)
          render_inertia_page(props: show_page_props)
        end

        # GET /settings/passkeys/new
        def new
          authorize!(ClientPasskey, to: :new?)
          @passkey = current_client.client_passkeys.new
          start_passkey_ceremony!(surface: "app", actor: current_client, session_ref: current_session_public_id)
          render_inertia_page(props: new_page_props)
        end

        # GET /settings/passkeys/:id/edit
        def edit
          set_passkey
          authorize!(@passkey)
          render_inertia_page(props: edit_page_props)
        end

        # POST /settings/passkeys
        # WebAuthn registration is driven by new/options/verification; REST create
        # hands clients to that ceremony without mutating local Sign state.
        def create
          @passkey = current_client.client_passkeys.new(description: passkey_description)
          authorize!(@passkey)

          respond_to do |format|
            format.html do
              redirect_to(
                new_auth_app_settings_passkey_path(ri: params[:ri]),
                status: :see_other,
              )
            end
            format.json do
              render json: { error: passkey_verification_required_message },
                     status: :unprocessable_content
            end
          end
        end

        # PATCH/PUT /settings/passkeys/:id
        def update
          set_passkey
          authorize!(@passkey)

          if @passkey.update(update_params)
            redirect_to(auth_app_settings_passkey_path(@passkey.public_id, ri: params[:ri]), status: :see_other)
          else
            render_inertia_page(
              component: "auth/app/settings/passkeys/edit",
              props: edit_page_props,
              status: :unprocessable_content,
            )
          end
        end

        # DELETE /settings/passkeys/:id
        def destroy
          passkey = current_client.client_passkeys.find_by!(public_id: params.expect(:id))
          authorize!(passkey)

          unless AuthMethodGuard.can_remove_passkey?(current_client, passkey)
            redirect_last_method
            return
          end

          passkey.destroy!
          redirect_to(
            auth_app_settings_passkeys_path(ri: params[:ri]),
            status: :see_other,
          )
        end

        private

        # Renders one Inertia page and tells `settings_passkeys_layout` that the slim Inertia shell
        # is the right layout for this response.
        def render_inertia_page(props:, component: true, status: :ok)
          @renders_inertia_page = true
          render inertia: component, props: props, status: status
        end

        def settings_passkeys_layout
          @renders_inertia_page ? "auth/app/inertia" : "auth/app/application"
        end

        def index_page_props
          {
            title: "Passkeys",
            back_link: { label: t("sign.app.settings.show.back"), href: auth_app_settings_path },
            new_link: {
              label: t("controller.sign.app.v1.passkey.new"),
              href: new_auth_app_settings_passkey_path(ri: params[:ri]),
            },
            columns: {
              description: t("activerecord.attributes.user_passkey.description"),
              created_at: t("activerecord.attributes.user_passkey.created_at"),
              last_used_at: t("activerecord.attributes.user_passkey.last_used_at"),
              actions: t("views.sign.app.settings.passkeys.index.actions"),
            },
            empty_message: t("views.sign.app.settings.passkeys.index.empty"),
            edit_label: t("actions.edit"),
            destroy_label: t("actions.destroy"),
            destroy_confirm: t("messages.confirm_destroy"),
            turnstile: turnstile_stealth_props,
            passkeys: @passkeys.map { |passkey| serialize_passkey_row(passkey) },
          }
        end

        def serialize_passkey_row(passkey)
          {
            public_id: passkey.public_id,
            description: passkey.description,
            created_at: l(passkey.created_at, format: :short),
            last_used_at: passkey.last_used_at ? l(passkey.last_used_at, format: :short) : "-",
            edit_href: edit_auth_app_settings_passkey_path(passkey.public_id, ri: params[:ri]),
            destroy_href: auth_app_settings_passkey_path(passkey.public_id, ri: params[:ri]),
          }
        end

        def show_page_props
          {
            title: t("sign.app.settings.passkeys.show.title"),
            description: t("sign.app.settings.passkeys.show.description"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: auth_app_settings_passkeys_path(ri: params[:ri]),
            },
            passkey_description: @passkey.description,
            details: [
              {
                key: "provider_name",
                label: t("activerecord.attributes.user_passkey.provider_name"),
                value: @passkey.provider_name.presence || t("sign.unknown_authenticator"),
              },
              {
                key: "created_at",
                label: t("activerecord.attributes.user_passkey.created_at"),
                value: l(@passkey.created_at, format: :long),
              },
              {
                key: "last_used_at",
                label: t("activerecord.attributes.user_passkey.last_used_at"),
                value: @passkey.last_used_at ? l(@passkey.last_used_at, format: :long) : t("defaults.never"),
              },
            ],
            edit_link: {
              label: t("actions.edit"),
              href: edit_auth_app_settings_passkey_path(@passkey.public_id, ri: params[:ri]),
            },
          }
        end

        def new_page_props
          {
            title: t("sign.app.settings.passkeys.new.page_title"),
            description: t("sign.app.settings.passkeys.new.description"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: auth_app_settings_passkeys_path(ri: params[:ri]),
            },
            cancel_link: { label: t("sign.common.cancel"), href: auth_app_settings_passkeys_path },
            panel: {
              options_url: auth_app_settings_passkeys_options_path,
              verification_url: auth_app_settings_passkeys_verification_path,
              turnstile_site_key: turnstile_stealth_props.fetch(:site_key),
              turnstile_error_message: t("turnstile_error"),
              description_label: t("sign.app.settings.passkeys.new.description_label"),
              description_placeholder: t("sign.app.settings.passkeys.new.description_placeholder"),
              submit_label: t("sign.app.settings.passkeys.new.submit"),
            },
          }
        end

        def edit_page_props
          {
            title: t("sign.app.settings.passkeys.edit.title"),
            description: t("sign.app.settings.passkeys.edit.description"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: auth_app_settings_passkeys_path(ri: params[:ri]),
            },
            form: {
              action: auth_app_settings_passkey_path(@passkey.public_id, ri: params[:ri]),
              scope: "client_passkey",
              description_label: t("activerecord.attributes.user_passkey.description"),
              description: @passkey.description,
              submit_label: t("actions.save"),
            },
            cancel_link: { label: t("sign.common.cancel"), href: auth_app_settings_passkeys_path },
            destroy: {
              action: auth_app_settings_passkey_path(@passkey.public_id, ri: params[:ri]),
              submit_label: t("actions.delete"),
              confirm_message: t("messages.confirm_destroy"),
            },
            turnstile: turnstile_stealth_props,
            error_header: passkey_error_header,
            error_messages: @passkey.errors.full_messages,
          }
        end

        def passkey_error_header
          return nil if @passkey.errors.empty?

          t("errors.messages.validation_errors", count: @passkey.errors.count)
        end

        def set_passkey
          @passkey = current_client.client_passkeys.find_by!(public_id: params.expect(:id))
        end

        def update_params
          key = %i(client_passkey user_passkey passkey).find { |candidate| params.key?(candidate) }
          return {} unless key

          params.fetch(key, {}).permit(:description)
        end

        def redirect_last_method
          redirect_to(
            auth_app_settings_passkeys_path(ri: params[:ri]),
            status: :see_other,
          )
        end

        def passkey_verification_required_message
          I18n.t("errors.webauthn.verification_required")
        end

        def passkey_registration_actor = current_client

        def passkey_registration_passkeys = current_client.client_passkeys

        def passkey_registration_redirect_url
          auth_app_settings_passkeys_url(ri: params[:ri], host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
        end

        def passkey_registration_log_prefix = "sign.webauthn.registration"
      end
    end
  end
end
