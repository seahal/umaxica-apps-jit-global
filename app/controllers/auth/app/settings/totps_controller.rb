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
        include ::AuthStepUpCeremonyContext

        include ::VerificationClient

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        declare_authentication_mode! :private, only: %i(index edit update destroy)
        layout :settings_totps_layout

        before_action :require_totp_registration_context!, only: %i(new create)

        def new
          authorize!(ClientTotpCredential, to: :new?, context: { user: @step_up_ceremony_actor })
          if @step_up_ceremony_transaction.verified?
            return redirect_to(auth_app_settings_totps_handoff_path(ri: params[:ri]), status: :see_other)
          end
          if ClientTotpCredential.slot_consuming.where(user_id: @step_up_ceremony_actor.id).count >=
              ClientTotpCredential::MAX_TOTP_SLOTS
            return render plain: t(
              "session_limit.totp_limit_reached", count: ClientTotpCredential::MAX_TOTP_SLOTS,
            )
          end

          # Display only: the secret belongs to an enrolment started by POST, never to this GET.
          @totp = ClientTotpCredential.new
          @totp_enrollment = IdentityTotpEnrollmentQuery.call(
            actor: @step_up_ceremony_actor, token: ceremony_session_token(@step_up_ceremony_session),
            transaction: @step_up_ceremony_transaction,
          )
          @png = generate_qrcode(@totp_enrollment.private_key) if @totp_enrollment
          render_inertia_page(props: new_page_props)
        end

        def create
          authorize!(ClientTotpCredential, to: :create?, context: { user: @step_up_ceremony_actor })
          discard_legacy_totp_enrollment!
          @totp_enrollment = IdentityTotpEnrollmentQuery.call(
            actor: @step_up_ceremony_actor, token: ceremony_session_token(@step_up_ceremony_session),
            transaction: @step_up_ceremony_transaction,
          )
          # A page from a cancelled, expired or replaced enrolment cannot confirm the current one.
          unless @totp_enrollment && submitted_totp_enrollment_id.is_a?(String) &&
              @totp_enrollment.ref == submitted_totp_enrollment_id
            return render plain: t("errors.messages.invalid_request"), status: :conflict
          end

          submitted = params.expect(user_totp_credential: %i(enrollment_id first_token title))
          @totp = ClientTotpCredential.new(title: submitted[:title], first_token: submitted[:first_token])

          unless cloudflare_turnstile_stealth_validation["success"]
            @totp.errors.add(:base, t("turnstile_error"))
            render_totp_qrcode(@totp_enrollment.private_key)
            render_new_totp_page_with_errors
            return
          end

          accepted = IdentityTotpEnrollmentVerificationCommitter.call!(
            actor: @step_up_ceremony_actor, token: ceremony_session_token(@step_up_ceremony_session),
            transaction: @step_up_ceremony_transaction, candidate_ref: @totp_enrollment.ref,
            code: submitted[:first_token], title: submitted[:title],
          )
          if accepted
            redirect_to(auth_app_settings_totps_handoff_path(ri: params[:ri]), status: :see_other)
          else
            handle_failure
          end
        rescue ClientTotpCredential::SlotLimitExceeded
          render plain: t(
            "session_limit.totp_limit_reached", count: ClientTotpCredential::MAX_TOTP_SLOTS,
          ), status: :unprocessable_content
        end

        private

        def handle_failure
          @totp.errors.add(:first_token, t("sign.app.settings.totps.invalid_code"))
          render_totp_qrcode(@totp_enrollment.private_key)
          render_new_totp_page_with_errors
        end

        def current_policy_user
          @step_up_ceremony_actor
        end

        def require_totp_registration_context!
          return unless load_registration_ceremony_context!
          return render_invalid_step_up_context! unless admitted_step_up_methods.include?(:totp)
          return if @step_up_ceremony_transaction.status == "pending" ||
            (@step_up_ceremony_transaction.verified? && @step_up_ceremony_transaction.method == "totp")

          render_invalid_step_up_context!
        end

        def ceremony_actor_model = Client

        def ceremony_step_up_session_model = ClientStepUpSession

        def ceremony_session_token(record) = record.user_token

        def ceremony_token_owned_by?(token, actor) = token.user_id == actor.id

        def ceremony_supported_methods = [:totp]

        def authorize_step_up_ceremony_actor!(actor)
          authorize!(actor, to: :show?, context: { user: actor })
        end

        rescue_from IdentityTotpCeremonyContract::Error, with: :render_invalid_step_up_context!
        rescue_from ActiveRecord::RecordNotFound, with: :render_missing_totp_record!

        def render_missing_totp_record!
          render_invalid_step_up_context!
        end

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

        def new_page_props
          {
            title: t("sign.app.settings.totp.new.page_title"),
            description: t("sign.app.settings.totp.new.description"),
            back_link: {
              label: t("sign.app.settings.show.back"),
              href: (@step_up_ceremony_transaction.purpose == "bootstrap") ?
                new_auth_app_verification_setup_path(ri: params[:ri]) :
                base_app_identity_url(ri: params[:ri], host: base_authority_host, protocol: "https"),
            },
            # Without an active enrolment the page offers only the explicit start. With one, the QR
            # code carries its secret; the encrypted candidate remains on the ticket writer.
            start: @totp_enrollment ? nil : {
              action: auth_app_settings_totps_enrollment_path(ri: params[:ri]),
              label: t("sign.app.settings.totp.index.new_link"),
            },
            qr_code_image: @totp_enrollment ? "data:image/png;base64,#{Base64.strict_encode64(@png.to_s)}" : nil,
            qr_fallback: t("views.sign.app.settings.totps.new.qr_fallback"),
            form: {
              action: auth_app_settings_totps_path(ri: params[:ri]),
              scope: "user_totp_credential",
              title_label: t("activerecord.attributes.user_totp_credential.title"),
              title_placeholder: t("messages.totp_title_placeholder"),
              title_hint: t("sign.app.settings.totp.new.title_hint"),
              title: @totp.title,
              enrollment_id: @totp_enrollment&.ref,
              first_token_label: t("views.sign.app.settings.totps.new.first_token_label"),
              first_token_placeholder: t("views.sign.app.settings.totps.new.first_token_placeholder"),
              first_token_help: t("views.sign.app.settings.totps.new.first_token_help"),
              first_token_delivery_help: t("views.sign.app.settings.totps.new.first_token_delivery_help"),
              submit_label: t("views.sign.app.settings.totps.new.submit"),
            },
            cancel: @totp_enrollment ? {
              label: t("actions.cancel"),
              action: auth_app_settings_totps_enrollment_path(ri: params[:ri]),
              method: "delete",
            } : nil,
            turnstile: turnstile_stealth_props,
            error_header: totp_error_header(model: true),
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

        def render_totp_qrcode(private_key)
          @png = generate_qrcode(private_key)
        end

        def generate_qrcode(private_key)
          totp = ROTP::TOTP.new(private_key)
          RQRCode::QRCode.new(totp.provisioning_uri(account_id)).as_png
        end

        def account_id
          @step_up_ceremony_actor.client_emails.first&.address || @step_up_ceremony_actor.public_id
        end

        def submitted_totp_enrollment_id
          params.dig(:user_totp_credential, :enrollment_id)
        end

        def verification_scope
          "settings_totp"
        end
      end
    end
  end
end
