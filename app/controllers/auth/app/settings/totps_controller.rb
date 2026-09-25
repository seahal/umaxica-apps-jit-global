# typed: false
# frozen_string_literal: true

require "rqrcode"

module Auth
  module App
    module Settings
      class TotpsController < ::Auth::App::ApplicationController
        include ::SurfaceInertiaPage
        include ::TurnstilePageProps
        include ::CloudflareTurnstile
        include ::SignAuthorityRedirect
        include ::SignSettingsTotpRegistration

        include ::VerificationClient

        AUTHENTICATION_MODE = :private
        TOTP_STATUS_TRANSLATION_KEYS = {
          ClientTotpCredentialStatus::ACTIVE => "messages.totp_status.active",
          ClientTotpCredentialStatus::INACTIVE => "messages.totp_status.inactive",
          ClientTotpCredentialStatus::REVOKED => "messages.totp_status.revoked",
          ClientTotpCredentialStatus::DELETED => "messages.totp_status.deleted",
          ClientTotpCredentialStatus::NOTHING => "messages.totp_status.nothing",
        }.freeze
        layout :settings_totps_layout

        before_action :authenticate_client!
        step_up only: %i(new create), bootstrap: true
        step_up only: :destroy

        def index
          authorize!(ClientTotpCredential, to: :index?)
          @totps = current_client.client_totp_credentials.order(created_at: :asc)
          render_inertia_page(props: index_page_props)
        end

        def new
          authorize!(ClientTotpCredential, to: :new?)
          if ClientTotpCredential.slot_consuming.where(user_id: current_client.id).count >=
              ClientTotpCredential::MAX_TOTP_SLOTS
            return render plain: t(
              "session_limit.totp_limit_reached", count: ClientTotpCredential::MAX_TOTP_SLOTS,
            )
          end

          @totp = ClientTotpCredential.new
          start_totp_ceremony!(_surface: "app", _actor: current_client, _session_ref: current_session_public_id)
          generate_totp_session
          render_inertia_page(props: new_page_props)
        end

        def edit
          find_totp
          authorize!(@totp)
          render_inertia_page(props: edit_page_props)
        end

        def create
          authorize!(ClientTotpCredential, to: :create?)
          initialize_totp

          if @totp.private_key.blank?
            redirect_to(
              new_auth_app_settings_totp_path,
            )
            return
          end

          unless cloudflare_turnstile_stealth_validation["success"]
            @totp.errors.add(:base, t("turnstile_error"))
            render_totp_qrcode(@totp.private_key)
            render_new_totp_page_with_errors
            return
          end

          last_otp_at = verify_totp(@totp.private_key, @totp.first_token)

          if last_otp_at
            handle_success(last_otp_at)
          else
            handle_failure
          end
        rescue ClientTotpCredential::SlotLimitExceeded
          render plain: t(
            "session_limit.totp_limit_reached", count: ClientTotpCredential::MAX_TOTP_SLOTS,
          ), status: :unprocessable_content
        end

        def initialize_totp
          @totp = ClientTotpCredential.new(totp_params)
          @totp.private_key = session[:private_key]
          @totp.user = current_client
          @totp.user_totp_credential_status_id = ClientTotpCredentialStatus::ACTIVE
        end

        def handle_success(last_otp_at)
          last_otp_at_time = Time.zone.at(last_otp_at)
          finish_totp_ceremony!(
            surface: "app",
            actor: current_client,
            session_ref: current_session_public_id,
            private_key: @totp.private_key,
            title: @totp.title,
            last_otp_at: last_otp_at_time,
          )
          session[:private_key] = nil
          reset_totp_ceremony_session!

          redirect_to(
            bootstrap_return_path(
              auth_app_settings_totps_url(
                ri: params[:ri],
                host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
              ),
            ),
            allow_other_host: cross_host_redirect_allowed?,
            status: :see_other,
          )
        end

        def handle_failure
          @totp.valid?
          @totp.errors.add(:first_token, t("sign.app.settings.totps.invalid_code"))
          render_totp_qrcode(@totp.private_key)
          render_new_totp_page_with_errors
        end

        def update
          find_totp
          authorize!(@totp)

          if @totp.update(update_params)
            redirect_to(auth_app_settings_totp_path(@totp.public_id, ri: params[:ri]), status: :see_other)
          else
            render_inertia_page(
              component: "auth/app/settings/totps/edit",
              props: edit_page_props,
              status: :unprocessable_content,
            )
          end
        end

        # DELETE /settings/totps/:id
        def destroy
          totp = current_client.client_totp_credentials.find_by!(public_id: params.expect(:id))
          authorize!(totp)
          unless AuthMethodGuard.can_remove_totp?(current_client, totp)
            redirect_to(
              auth_app_settings_totps_path(ri: params[:ri]),
              status: :see_other,
            )
            return
          end
          totp.destroy!
          redirect_to(auth_app_settings_totps_path(ri: params[:ri]), status: :see_other)
        end

        private

        # Renders one Inertia page and tells `settings_totps_layout` that the slim Inertia shell is
        # the right layout for this response.
        def render_inertia_page(props:, component: true, status: :ok)
          @renders_inertia_page = true
          render inertia: component, props: props, status: status
        end

        def settings_totps_layout
          @renders_inertia_page ? "auth/app/inertia" : "auth/app/application"
        end

        def render_new_totp_page_with_errors
          render_inertia_page(
            component: "auth/app/settings/totps/new",
            props: new_page_props,
            status: :unprocessable_content,
          )
        end

        def index_page_props
          {
            title: "Totps",
            back_link: { label: t("sign.app.settings.show.back"), href: auth_app_settings_path },
            new_link: {
              label: t("sign.app.settings.totp.index.new_link"),
              href: new_auth_app_settings_totp_path(ri: params[:ri]),
            },
            columns: {
              title: t("activerecord.attributes.user_totp_credential.title"),
              last_otp_at: t("activerecord.attributes.user_totp_credential.last_otp_at"),
              status: t("messages.totp_status_label"),
              actions: "Actions",
            },
            empty_message: t("messages.no_totp_found"),
            edit_label: t("actions.edit"),
            totps: @totps.map { |credential| serialize_totp_row(credential) },
          }
        end

        def serialize_totp_row(credential)
          {
            public_id: credential.public_id,
            title: credential.title.presence,
            last_otp_at: formatted_last_otp_at(credential),
            status: totp_status_label(credential),
            edit_href: edit_auth_app_settings_totp_path(credential.public_id, ri: params[:ri]),
          }
        end

        def totp_status_label(credential)
          translation_key = TOTP_STATUS_TRANSLATION_KEYS.fetch(
            credential.user_identity_totp_credential_status_id,
            TOTP_STATUS_TRANSLATION_KEYS.fetch(ClientTotpCredentialStatus::NOTHING),
          )
          t(translation_key)
        end

        # A credential that has never produced a code carries nil, so it reads as "never used"
        # without storing a sentinel timestamp for an event that has not occurred.
        def formatted_last_otp_at(credential)
          last_otp_at = credential.last_otp_at
          usable =
            (last_otp_at.is_a?(Time) || last_otp_at.is_a?(ActiveSupport::TimeWithZone)) &&
            last_otp_at > Time.zone.at(0)

          usable ? l(last_otp_at, format: :short) : "-"
        end

        def new_page_props
          {
            title: t("sign.app.settings.totp.new.page_title"),
            description: t("sign.app.settings.totp.new.description"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: auth_app_settings_totps_path(ri: params[:ri]),
            },
            # The provisioning QR code is the same image the enrolment page already displayed; the
            # shared secret itself never leaves the session.
            qr_code_image: "data:image/png;base64,#{Base64.strict_encode64(@png.to_s)}",
            qr_fallback: t("views.sign.app.settings.totps.new.qr_fallback"),
            form: {
              action: auth_app_settings_totps_path(ri: params[:ri]),
              scope: "user_totp_credential",
              title_label: t("activerecord.attributes.user_totp_credential.title"),
              title_placeholder: t("messages.totp_title_placeholder"),
              title_hint: t("sign.app.settings.totp.new.title_hint"),
              title: @totp.title,
              first_token_label: t("views.sign.app.settings.totps.new.first_token_label"),
              first_token_placeholder: t("views.sign.app.settings.totps.new.first_token_placeholder"),
              first_token_help: t("views.sign.app.settings.totps.new.first_token_help"),
              first_token_delivery_help: t("views.sign.app.settings.totps.new.first_token_delivery_help"),
              submit_label: t("views.sign.app.settings.totps.new.submit"),
            },
            cancel_link: {
              label: t("actions.cancel"),
              href: auth_app_settings_totps_path(ri: params[:ri]),
            },
            turnstile: turnstile_stealth_props,
            error_header: totp_error_header(model: true),
            error_messages: @totp.errors.full_messages,
          }
        end

        def edit_page_props
          {
            title: t("sign.app.setting.totp.edit.title"),
            description: t("sign.app.setting.totp.edit.description"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: auth_app_settings_totps_path(ri: params[:ri]),
            },
            form: {
              action: auth_app_settings_totp_path(@totp.public_id, ri: params[:ri]),
              scope: "user_totp_credential",
              title_label: t("activerecord.attributes.user_totp_credential.title"),
              title_placeholder: t("messages.totp_title_placeholder"),
              title_hint: t("sign.app.setting.totp.edit.title_hint"),
              title: @totp.title,
              submit_label: t("actions.save"),
            },
            cancel_link: {
              label: t("actions.cancel"),
              href: auth_app_settings_totps_path(ri: params[:ri]),
            },
            destroy: {
              action: auth_app_settings_totp_path(@totp.public_id, ri: params[:ri]),
              submit_label: t("actions.delete"),
              confirm_message: t("messages.confirm_delete_totp"),
            },
            error_header: totp_error_header(model: false),
            error_messages: @totp.errors.full_messages,
          }
        end

        def totp_error_header(model:)
          return nil if @totp.errors.empty?

          if model
            t("errors.template.header", model: @totp.model_name.human, count: @totp.errors.count)
          else
            t("errors.template.header", count: @totp.errors.count)
          end
        end

        def find_totp
          @totp = current_client.client_totp_credentials.find_by!(public_id: params.expect(:id))
        end

        def generate_totp_session
          session[:private_key] ||= ROTP::Base32.random_base32
          @png = generate_qrcode(session[:private_key])
        end

        def render_totp_qrcode(private_key)
          @png = generate_qrcode(private_key)
        end

        def generate_qrcode(private_key)
          totp = ROTP::TOTP.new(private_key)
          RQRCode::QRCode.new(totp.provisioning_uri(account_id)).as_png
        end

        def verify_totp(private_key, token)
          ROTP::TOTP.new(private_key).verify(normalized_totp_token(token))
        end

        def normalized_totp_token(token)
          token.to_s.gsub(/\D/, "")
        end

        def account_id
          current_client.client_emails.first&.address || current_client.public_id
        end

        def totp_params
          params(user_totp_credential: [:first_token, :title])
        end

        def update_params
          params(user_totp_credential: [:title])
        end

        def verification_required_action?
          step_up_bootstrap_active? && %w(new create).include?(action_name)
        end

        def verification_scope
          "settings_totp"
        end

        private :initialize_totp, :handle_success, :handle_failure
      end
    end
  end
end
