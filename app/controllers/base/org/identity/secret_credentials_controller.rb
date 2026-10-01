# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Identity
      class SecretCredentialsController < ::Base::Org::ApplicationController
        include ::VerificationOperator

        include ::SignSettingsSecretCredentialTurnstileGuard

        include ::SignSettingsSecretCredentialCacheControl
        include ::SignAuthorityRedirect
        include ::SignSettingsSecretCredentialRegistration
        include ::SurfaceInertiaPage
        include ::TurnstilePageProps

        AUTHENTICATION_MODE = :private

        before_action :authenticate_operator!
        step_up only: %i(new create), bootstrap: true
        step_up only: %i(edit update destroy)
        before_action :set_no_store_for_secret_credential_pages
        before_action :set_secret_credential, only: %i(show edit update destroy)
        before_action :verify_secret_credential_turnstile!, only: :create

        def index
          authorize!(OperatorSecretCredential, to: :index?)
          @secret_credentials = current_operator.staff_secret_credentials.order(created_at: :asc)
          render inertia: true, props: index_page_props
        end

        def show
          authorize!(@secret_credential)
          render inertia: true, props: show_page_props
        end

        def new
          authorize!(OperatorSecretCredential, to: :new?)
          @secret_credential = current_operator.staff_secret_credentials.new
          start_secret_credential_ceremony!(
            _surface: "org", _actor: current_operator,
            _session_ref: current_session_public_id,
          )
          @raw_secret_credential = OperatorSecretCredential.generate_raw_secret_credential
          session[:staff_secret_credential_raw] = @raw_secret_credential
          @secret_credential.name = @raw_secret_credential.first(4)
          render inertia: true, props: new_page_props
        end

        def edit
          authorize!(@secret_credential)
          render inertia: true, props: edit_page_props
        end

        def create
          authorize!(OperatorSecretCredential, to: :create?)
          raw_secret_credential = session.delete(:staff_secret_credential_raw)
          finish_secret_credential_ceremony!(
            surface: "org",
            actor: current_operator,
            session_ref: current_session_public_id,
            record_class: OperatorSecretCredential,
            name: secret_credential_params[:name].to_s.strip,
            enabled: secret_credential_params[:enabled],
            raw_secret_credential: raw_secret_credential,
          )
          reset_secret_credential_ceremony_session!

          redirect_to_surface_url(
            base_org_identity_secrets_url(
              ri: params[:ri],
              host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
            ),
          )
        rescue ActiveRecord::RecordInvalid => e
          @secret_credential = e.record
          @raw_secret_credential = raw_secret_credential.presence ||
            OperatorSecretCredential.generate_raw_secret_credential
          session[:staff_secret_credential_raw] = @raw_secret_credential
          render inertia: "base/org/identity/secret_credentials/new",
                 props: new_page_props,
                 status: :unprocessable_content
        end

        def update
          authorize!(@secret_credential)

          if disabling_secret_credential? && AuthMethodGuard.last_method?(
            current_operator,
            excluding: @secret_credential,
          )
            redirect_to(
              base_org_identity_secret_path(@secret_credential.public_id, ri: params[:ri]),
              status: :see_other,
            )
            return
          end

          result = OperatorSecretCredentialsUpdate.call(
            actor: current_operator,
            secret_credential: @secret_credential,
            params: secret_credential_params,
          )
          redirect_to(
            base_org_identity_secret_path(result.secret_credential.public_id, ri: params[:ri]),
            status: :see_other,
          )
        end

        def destroy
          authorize!(@secret_credential)
          unless AuthMethodGuard.can_remove_secret_credential?(current_operator, @secret_credential)
            redirect_to(
              base_org_identity_secrets_path(ri: params[:ri]),
              status: :see_other,
            )
            return
          end
          OperatorSecretCredentialsDestroy.call(actor: current_operator, secret_credential: @secret_credential)
          redirect_to(base_org_identity_secrets_path(ri: params[:ri]), status: :see_other)
        end

        private

        def index_page_props
          {
            title: t("base.org.identity.secret_credentials.index.title"),
            description: t("base.org.identity.secret_credentials.index.description"),
            new_link: {
              label: t("base.org.identity.secret_credentials.index.new"),
              href: new_base_org_identity_secret_path(ri: params[:ri]),
            },
            columns: {
              name: t("activerecord.attributes.staff_secret_credential.name"),
              created_at: t("activerecord.attributes.staff_secret_credential.created_at"),
              last_used_at: t("activerecord.attributes.staff_secret_credential.last_used_at"),
              actions: "Actions",
            },
            edit_label: t("actions.edit"),
            destroy_label: t("actions.destroy"),
            destroy_confirm: t("messages.confirm_destroy"),
            turnstile: turnstile_stealth_props,
            secret_credentials: @secret_credentials.map { |record| serialize_secret_credential(record) },
          }
        end

        def serialize_secret_credential(record)
          {
            public_id: record.public_id,
            name: record.name,
            created_at: l(record.created_at, format: :short),
            last_used_at: record.last_used_at ? l(record.last_used_at, format: :short) : "-",
            edit_href: edit_base_org_identity_secret_path(record.public_id, ri: params[:ri]),
            destroy_href: base_org_identity_secret_path(record.public_id, ri: params[:ri]),
          }
        end

        def show_page_props
          {
            title: t("base.org.identity.secret_credentials.show.title"),
            description: t("base.org.identity.secret_credentials.show.description"),
            name: @secret_credential.name,
            created_at_label: t("activerecord.attributes.staff_secret_credential.created_at"),
            created_at: l(@secret_credential.created_at, format: :long),
            last_used_at_label: t("activerecord.attributes.staff_secret_credential.last_used_at"),
            last_used_at: @secret_credential.last_used_at ? l(
              @secret_credential.last_used_at,
              format: :long,
            ) : t("defaults.never"),
            back_link: {
              label: t("actions.back"),
              href: base_org_identity_secrets_path(ri: params[:ri]),
            },
            edit_link: {
              label: t("actions.edit"),
              href: edit_base_org_identity_secret_path(@secret_credential.public_id, ri: params[:ri]),
            },
          }
        end

        def new_page_props
          {
            title: t("base.org.identity.secret_credentials.new.title"),
            description: t("base.org.identity.secret_credentials.new.description"),
            form: {
              action: base_org_identity_secrets_path,
              scope: "staff_secret_credential",
              name: @secret_credential.name,
              name_label: OperatorSecretCredential.human_attribute_name(:name),
              value_label: t("activerecord.attributes.staff_secret_credential.value"),
              confirm_saved_label:
                t("views.sign.org.settings.secret_credentials.new.confirm_secret_credential_saved_label"),
              submit: t("actions.save"),
            },
            cancel_link: { label: t("actions.cancel"), href: base_org_identity_secrets_path },
            turnstile: turnstile_stealth_props,
            error_header: secret_credential_error_header,
            error_messages: @secret_credential.errors.full_messages,
          }
        end

        def edit_page_props
          {
            title: t("base.org.identity.secret_credentials.edit.title"),
            description: t("base.org.identity.secret_credentials.edit.description"),
            form: {
              action: base_org_identity_secret_path(@secret_credential.public_id, ri: params[:ri]),
              scope: "staff_secret_credential",
              method: "patch",
              name: @secret_credential.name,
              name_label: OperatorSecretCredential.human_attribute_name(:name),
              submit: t("actions.update"),
            },
            cancel_link: {
              label: t("actions.cancel"),
              href: base_org_identity_secrets_path(ri: params[:ri]),
            },
            turnstile: turnstile_stealth_props,
            error_header: secret_credential_error_header,
            error_messages: @secret_credential.errors.full_messages,
          }
        end

        def secret_credential_error_header
          return nil if @secret_credential.errors.empty?

          t(
            "errors.template.header",
            model: @secret_credential.model_name.human,
            count: @secret_credential.errors.count,
          )
        end

        def set_secret_credential
          @secret_credential = current_operator.staff_secret_credentials.find_by!(public_id: params.expect(:id))
        end

        def secret_credential_params
          params.fetch(:staff_secret_credential, {}).permit(:name, :enabled)
        end

        def disabling_secret_credential?
          secret_credential_params.key?(:enabled) && !ActiveModel::Type::Boolean.new.cast(secret_credential_params[:enabled])
        end

        def prepare_secret_credential_turnstile_create_failure
          @secret_credential = current_operator.staff_secret_credentials.new(secret_credential_params.except(:enabled))
          @raw_secret_credential = session[:staff_secret_credential_raw].presence ||
            OperatorSecretCredential.generate_raw_secret_credential
          session[:staff_secret_credential_raw] = @raw_secret_credential
          @secret_credential.name = @raw_secret_credential.first(4) if @secret_credential.name.blank?
          @secret_credential.errors.add(:base, t("turnstile_error"))
        end

        def render_secret_credential_turnstile_create_failure
          render inertia: "base/org/identity/secret_credentials/new",
                 props: new_page_props,
                 status: :unprocessable_content
        end

        def verification_required_action?
          action_name == "create"
        end

        def verification_scope
          "settings_secret_credential"
        end
      end
    end
  end
end
