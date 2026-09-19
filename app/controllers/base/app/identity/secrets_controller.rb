# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class SecretsController < BaseController
        include ::SurfaceInertiaPage
        include CloudflareTurnstile
        include VerificationClient
        # `new` and `create` call start_secret_credential_ceremony! /
        # reset_secret_credential_ceremony_session!, which live here. Without the include both
        # actions raise NoMethodError. The com and org secret credential controllers already
        # include it; this keeps the three surfaces on the same seam.
        include ::SignSettingsSecretCredentialRegistration
        # `new` renders the freshly generated plaintext recovery secret as an Inertia prop, which
        # inertia_rails serializes into the initial document. Without `no-store` a Back navigation
        # or a restored tab re-renders that plaintext from the browser cache after the ceremony
        # finished. The com and org secret credential controllers already carry this concern.
        include ::SignSettingsSecretCredentialCacheControl

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_client!
        before_action :set_no_store_for_secret_credential_pages
        before_action :authorize_secret_credentials!, only: %i(index show new edit create update destroy)
        step_up only: %i(new create), bootstrap: true
        step_up only: %i(edit update destroy)
        def index
          secret_credentials = current_client.client_secret_credentials.order(created_at: :asc)
          render inertia: true, props: secrets_index_props(secret_credentials)
        end

        def show
          set_secret_credential
          authorize!(@secret_credential)
          render inertia: true, props: secret_show_props(@secret_credential)
        end

        def new
          authorize!(ClientSecretCredential, to: :new?)
          @secret_credential = current_client.client_secret_credentials.new
          start_secret_credential_ceremony!(
            _surface: "app", _actor: current_client,
            _session_ref: current_session_public_id,
          )
          raw_secret_credential = ClientSecretCredential.generate_raw_secret_credential
          session[:user_secret_credential_raw] = raw_secret_credential
          @secret_credential.name = raw_secret_credential.first(4)
          render inertia: true, props: secret_new_props(@secret_credential, raw_secret_credential)
        end

        def edit
          set_secret_credential
          authorize!(@secret_credential)
          render inertia: true, props: secret_edit_props(@secret_credential)
        end

        def create
          authorize!(ClientSecretCredential, to: :create?)
          result = ClientSecretCredentialsCreate.call(
            actor: current_client,
            user: current_client,
            params: secret_credential_params,
            raw_secret_credential: session.delete(:user_secret_credential_raw),
          )
          reset_secret_credential_ceremony_session!
          redirect_to(
            base_app_identity_secret_path(result.secret_credential.public_id, ri: params[:ri]),
            status: :see_other,
          )
        end

        def update
          set_secret_credential; authorize!(@secret_credential)
          result = ClientSecretCredentialsUpdate.call(
            actor: current_client, secret_credential: @secret_credential,
            params: secret_credential_params,
          )
          result.secret_credential.errors.empty? ? redirect_to(
            base_app_identity_secret_path(
              result.secret_credential.public_id,
              ri: params[:ri],
            ), status: :see_other,
          ) : render(
            inertia: "base/app/identity/secrets/edit",
            props: secret_edit_props(result.secret_credential),
            status: :unprocessable_content,
          )
        end

        def destroy
          secret_credential = current_client.client_secret_credentials.find_by!(public_id: params.expect(:id))
          authorize!(secret_credential)
          return redirect_to(
            base_app_identity_secrets_path(ri: params[:ri]),
            status: :see_other,
          ) unless AuthMethodGuard.can_remove_secret_credential?(
            current_client, secret_credential,
          )

          ClientSecretCredentialsDestroy.call(actor: current_client, secret_credential: secret_credential)
          redirect_to(base_app_identity_secrets_path(ri: params[:ri]), status: :see_other)
        end

        private

        # `step_up` above hands this to require_verification!, which calls to_sym on it. Without a
        # scope `new` and `create` raise NoMethodError on nil. The com and org secret credential
        # controllers name the same scope.
        def verification_scope = "settings_secret_credential"

        def authorize_secret_credentials! = authorize!(ClientSecretCredential, to: :index?)

        def set_secret_credential
          @secret_credential = current_client.client_secret_credentials.find_by!(public_id: params.expect(:id))
        end

        def secret_credential_params = params.fetch(:user_secret_credential, {}).permit(:name, :enabled)

        def secrets_index_props(secret_credentials)
          {
            title: "Secrets",
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: base_app_identity_path(ri: params[:ri]),
            },
            new_link: { label: "New secret", href: new_base_app_identity_secret_path },
            table_headings: {
              name: "Name",
              created_at: "Created",
              last_used_at: "Last used",
              actions: "Actions",
            },
            edit_label: t("actions.edit"),
            destroy_label: t("actions.destroy"),
            destroy_confirm: t("messages.confirm_destroy"),
            secret_credentials: secret_credentials.map { |secret_credential| serialize_secret(secret_credential) },
          }
        end

        def serialize_secret(secret_credential)
          {
            public_id: secret_credential.public_id,
            name: secret_credential.name.to_s,
            created_at: I18n.l(secret_credential.created_at, format: :short),
            last_used_at: secret_credential.last_used_at ? I18n.l(secret_credential.last_used_at, format: :short) : "-",
            edit_url: edit_base_app_identity_secret_path(secret_credential.public_id, ri: params[:ri]),
            destroy_url: base_app_identity_secret_path(secret_credential.public_id, ri: params[:ri]),
          }
        end

        def secret_show_props(secret_credential)
          {
            title: "Secret",
            description: t("base.app.identity.secrets.show.description"),
            name: secret_credential.name.to_s,
            created_at_label: "Created",
            created_at: I18n.l(secret_credential.created_at, format: :long),
            last_used_at_label: "Last used",
            last_used_at: secret_credential.last_used_at ?
              I18n.l(secret_credential.last_used_at, format: :long) : t("defaults.never"),
            back_link: { label: t("actions.back"), href: base_app_identity_secrets_path },
            edit_link: {
              label: t("actions.edit"),
              href: edit_base_app_identity_secret_path(secret_credential.public_id),
            },
          }
        end

        def secret_new_props(secret_credential, raw_secret_credential)
          {
            title: "New secret",
            description: t("base.app.identity.secrets.new.description"),
            back_link: { label: t("actions.back"), href: base_app_identity_path(ri: params[:ri]) },
            cancel_link: { label: "Cancel", href: base_app_identity_secrets_path },
            form: {
              action: base_app_identity_secrets_path,
              name_label: "Name",
              name: secret_credential.name.to_s,
              enabled_label: t("views.sign.app.settings.secret_credentials.new.confirm_saved_label"),
              submit_label: t("actions.save"),
            },
            raw_secret_credential: raw_secret_credential,
            raw_secret_label: "Secret",
            one_time_notice: t("views.sign.app.settings.secret_credentials.new.one_time_notice"),
            errors: secret_credential.errors.full_messages,
          }
        end

        def secret_edit_props(secret_credential)
          {
            title: "Edit secret",
            description: t("base.app.identity.secrets.edit.description"),
            back_link: { label: t("actions.back"), href: base_app_identity_path(ri: params[:ri]) },
            cancel_link: { label: "Cancel", href: base_app_identity_secrets_path },
            form: {
              action: base_app_identity_secret_path(secret_credential.public_id, ri: params[:ri]),
              name_label: "Name",
              name: secret_credential.name.to_s,
              enabled_label: "Enabled",
              enabled: secret_credential.enabled?,
              submit_label: "Update",
            },
            errors: secret_credential.errors.full_messages,
          }
        end
      end
    end
  end
end
