# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class SecretCredentialsController < ::Base::Com::ApplicationController
        include ::SurfaceInertiaPage
        include ::TurnstilePageProps
        include ::VerificationVisitor

        include ::SignSettingsSecretCredentialTurnstileGuard

        include ::SignSettingsSecretCredentialCacheControl
        include ::SignSettingsSecretCredentialRegistration

        AUTHENTICATION_MODE = :private

        step_up only: %i(new create), bootstrap: true
        step_up only: %i(edit update destroy)
        before_action :set_no_store_for_secret_credential_pages
        before_action :set_secret_credential, only: %i(show edit update destroy)
        before_action :ensure_verified_recovery_identity_for_registration!, only: [:new]
        before_action :verify_secret_credential_turnstile!, only: :create

        def index
          authorize!(VisitorSecretCredential, to: :index?)
          @secret_credentials = current_visitor.visitor_secret_credentials.order(created_at: :asc)
          render inertia: true, props: index_page_props
        end

        def show
          authorize!(@secret_credential)
          render inertia: true, props: show_page_props
        end

        def new
          authorize!(VisitorSecretCredential, to: :new?)
          @secret_credential = current_visitor.visitor_secret_credentials.new
          start_secret_credential_ceremony!(
            _surface: "com", _actor: current_visitor,
            _session_ref: current_session_public_id,
          )
          @raw_secret_credential = VisitorSecretCredential.generate_raw_secret_credential
          session[:visitor_secret_credential_raw] = @raw_secret_credential
          @secret_credential.name = @raw_secret_credential.first(4)
          render inertia: true, props: new_page_props
        end

        def edit
          authorize!(@secret_credential)
          render inertia: true, props: edit_page_props
        end

        def create
          authorize!(VisitorSecretCredential, to: :create?)
          raw_secret_credential = session.delete(:visitor_secret_credential_raw)
          finish_secret_credential_ceremony!(
            surface: "com",
            actor: current_visitor,
            session_ref: current_session_public_id,
            record_class: VisitorSecretCredential,
            name: create_secret_credential_params[:name].to_s.strip,
            enabled: secret_credential_params[:enabled],
            raw_secret_credential: raw_secret_credential,
          )
          reset_secret_credential_ceremony_session!

          redirect_to_surface_url(
            base_com_identity_secrets_url(
              ri: params[:ri],
              host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
            ),
          )
        rescue ActiveRecord::RecordInvalid => e
          @secret_credential ||= e.record
          @raw_secret_credential ||= raw_secret_credential
          render_new_failure
        end

        def update
          authorize!(@secret_credential)

          blocked = false
          current_visitor.with_lock do
            @secret_credential = VisitorSecretCredential.lock.find_by!(
              id: @secret_credential.id, visitor_id: current_visitor.id,
            )
            blocked = disabling_secret_credential?(secret_credential_params) &&
              !AuthMethodGuard.can_remove_secret_credential?(current_visitor, @secret_credential)
            apply_secret_credential_update! unless blocked
          end

          if blocked
            redirect_to(
              base_com_identity_secret_path(@secret_credential.public_id, ri: params[:ri]),
              status: :see_other,
            )
            return
          end

          redirect_to(
            base_com_identity_secret_path(@secret_credential.public_id, ri: params[:ri]),
            status: :see_other,
          )
        end

        def destroy
          authorize!(@secret_credential)
          current_visitor.with_lock do
            @secret_credential = VisitorSecretCredential.lock.find_by!(
              id: @secret_credential.id, visitor_id: current_visitor.id,
            )
            unless AuthMethodGuard.can_remove_secret_credential?(current_visitor, @secret_credential)
              return redirect_to(
                base_com_identity_secrets_path(ri: params[:ri]),
                status: :see_other,
              )
            end

            @secret_credential.discard_now!(purge_after: 1.day)
            @secret_credential.visitor_secret_credential_status_id = VisitorSecretCredential.status_id_for(:deleted)
            @secret_credential.save!
          end
          redirect_to(base_com_identity_secrets_path(ri: params[:ri]), status: :see_other)
        end

        private

        # The failed create stays on the same page and the same 422 the ERB flow answered with.
        def render_new_failure
          render inertia: "base/com/identity/secret_credentials/new",
                 props: new_page_props,
                 status: :unprocessable_content
        end

        def index_page_props
          {
            title: "Secrets",
            back_link: { label: "Back", href: base_com_identity_path(ri: params[:ri]) },
            new_link: { label: "New", href: new_base_com_identity_secret_path(ri: params[:ri]) },
            columns: { name: "Name", created: "Created", last_used: "Last used", actions: "Actions" },
            destroy_confirm: t("messages.confirm_destroy"),
            destroy_label: t("actions.destroy"),
            turnstile: turnstile_stealth_props,
            credentials: @secret_credentials.map { |credential| serialize_credential_row(credential) },
          }
        end

        def serialize_credential_row(credential)
          {
            public_id: credential.public_id,
            name: credential.name,
            created_at: l(credential.created_at, format: :short),
            last_used_at: credential.last_used_at ? l(credential.last_used_at, format: :short) : "-",
            show_link: {
              label: "Show",
              href: base_com_identity_secret_path(credential.public_id, ri: params[:ri]),
            },
            edit_link: {
              label: t("actions.edit"),
              href: edit_base_com_identity_secret_path(credential.public_id, ri: params[:ri]),
            },
            destroy_url: base_com_identity_secret_path(credential.public_id, ri: params[:ri]),
          }
        end

        def show_page_props
          {
            title: "Secret",
            name: @secret_credential.name,
            created_term: "Created",
            created_at: l(@secret_credential.created_at, format: :long),
            last_used_term: "Last used",
            last_used_at: if @secret_credential.last_used_at
                            l(@secret_credential.last_used_at, format: :long)
                          else
                            t("defaults.never")
                          end,
            back_link: { label: "Back", href: base_com_identity_secrets_path(ri: params[:ri]) },
            edit_link: {
              label: t("actions.edit"),
              href: edit_base_com_identity_secret_path(@secret_credential.public_id, ri: params[:ri]),
            },
          }
        end

        # The raw secret is shown exactly once, on this page, to the owner who just generated it.
        # That is the same disclosure the ERB made; nothing else about it is persisted in props.
        def new_page_props
          {
            title: t("sign.app.settings.secret_credentials.new.title"),
            description: t("sign.app.settings.secret_credentials.new.description"),
            errors: secret_credential_error_props,
            form: {
              url: base_com_identity_secrets_path(ri: params[:ri]),
              method: "post",
              scope: "visitor_secret_credential",
              submit_label: t("actions.save"),
            },
            name_label: VisitorSecretCredential.human_attribute_name(:name),
            name_value: @secret_credential.name.to_s,
            enabled_label: t("views.sign.app.settings.secret_credentials.new.confirm_saved_label"),
            enabled: false,
            secret: {
              label: "Secret",
              value: @raw_secret_credential.to_s,
              one_time_notice: t("views.sign.app.settings.secret_credentials.new.one_time_notice"),
            },
            cancel_link: { label: t("actions.cancel"), href: base_com_identity_secrets_path(ri: params[:ri]) },
            turnstile: turnstile_stealth_props,
          }
        end

        def edit_page_props
          {
            title: t("sign.app.settings.secret_credentials.edit.title"),
            description: t("sign.app.settings.secret_credentials.edit.description"),
            errors: secret_credential_error_props,
            form: {
              url: base_com_identity_secret_path(@secret_credential.public_id, ri: params[:ri]),
              method: "patch",
              scope: "visitor_secret_credential",
              submit_label: t("actions.update"),
            },
            name_label: VisitorSecretCredential.human_attribute_name(:name),
            name_value: @secret_credential.name.to_s,
            enabled_label: VisitorSecretCredential.human_attribute_name(:enabled),
            # `enabled` was never a column: the ERB checkbox mapped to the credential status, and
            # `apply_secret_credential_update!` turns it back into that status on the way in.
            enabled: @secret_credential.visitor_secret_credential_status_id ==
              VisitorSecretCredentialStatus::ACTIVE,
            cancel_link: { label: t("actions.cancel"), href: base_com_identity_secrets_path(ri: params[:ri]) },
            turnstile: turnstile_stealth_props,
          }
        end

        def secret_credential_error_props
          messages = @secret_credential.errors.full_messages
          return if messages.empty?

          {
            header: t(
              "errors.template.header",
              model: @secret_credential.model_name.human,
              count: @secret_credential.errors.count,
            ),
            messages: messages,
          }
        end

        def set_secret_credential
          @secret_credential = current_visitor.visitor_secret_credentials.find_by!(public_id: params.expect(:id))
        end

        def secret_credential_params
          params.fetch(:visitor_secret_credential, params.fetch(:user_secret_credential, {})).permit(:name, :enabled)
        end

        def create_secret_credential_params
          secret_credential_params.except(:enabled)
        end

        def disabling_secret_credential?(params)
          params.key?(:enabled) && !ActiveModel::Type::Boolean.new.cast(params[:enabled])
        end

        def apply_secret_credential_update!
          attrs = secret_credential_params
          @secret_credential.name = attrs[:name].to_s.strip if attrs[:name].present?
          if attrs.key?(:enabled)
            status = ActiveModel::Type::Boolean.new.cast(attrs[:enabled]) ? :active : :revoked
            @secret_credential.visitor_secret_credential_status_id = VisitorSecretCredential.status_id_for(status)
          end
          @secret_credential.save!
        end

        def ensure_verified_recovery_identity_for_registration!
          return if current_visitor.has_verified_recovery_identity?

          render plain: Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE, status: :forbidden
        end

        def prepare_secret_credential_turnstile_create_failure
          @secret_credential = current_visitor.visitor_secret_credentials.new(create_secret_credential_params)
          @raw_secret_credential = session[:visitor_secret_credential_raw].presence ||
            VisitorSecretCredential.generate_raw_secret_credential
          session[:visitor_secret_credential_raw] = @raw_secret_credential
          @secret_credential.name = @raw_secret_credential.first(4) if @secret_credential.name.blank?
          @secret_credential.errors.add(:base, t("turnstile_error"))
        end

        def render_secret_credential_turnstile_create_failure
          render_new_failure
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
