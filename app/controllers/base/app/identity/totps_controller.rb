# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      class TotpsController < BaseController
        include ::SurfaceInertiaPage
        include ::BaseStepUpTransactionMarker

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        step_up only: :destroy, scope: "settings_totp"

        public

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

        def new
          authorize!(ClientTotpCredential, to: :new?)
          apply_base_browser_continuation_headers!
          restart_binding = base_registration_restart_binding!(scope: "settings_totp", method: :totp)
          render "base/shared/credential_registration", layout: false,
                                                        locals: {
                                                          action_url: base_app_identity_totps_path(ri: params[:ri]),
                                                          restart_binding:,
                                                        }
        rescue BaseAuthAdmissionCoordinator::Denied, ArgumentError, ActiveRecord::RecordNotFound
          render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
        end

        def create
          authorize!(ClientTotpCredential, to: :create?)
          apply_base_browser_continuation_headers!
          token = current_session_token
          requirement = totp_registration_requirement(token)
          issuance = BaseStepUpAdmissionIssuer.call!(
            actor: current_client, token: token, requirement: requirement,
            return_to: base_app_identity_totps_path,
            base_browser_nonce: ensure_base_admission_browser_nonce!, base_token: token,
            restart_of: params[:restart_of],
          )
          if issuance.is_a?(BaseAuthAdmissionCoordinator::TerminalOutcome)
            return redirect_to(issuance.transaction.return_to, status: :see_other, allow_other_host: false)
          end

          remember_base_step_up_transaction!(transaction: issuance.transaction, actor: current_client, token: token)
          redirect_to(
            new_auth_app_settings_totp_url(
              entry_ref: issuance.reference, ri: params[:ri],
              host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), protocol: "https",
            ), status: :see_other, allow_other_host: true,
          )
        rescue BaseAuthAdmissionCoordinator::Denied, ArgumentError, ActiveRecord::RecordNotFound
          render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
        rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
          render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
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

        def totp_registration_requirement(token)
          StepUpRequirement.new(
            scope: "settings_totp", purpose: "credential_registration", step_up_required: false,
            allowed_methods: [:totp], phishing_resistant_required: false,
            user_verification_required: false, full_reauthentication_required: false,
            audience: "step_up:app", session_binding: token.public_id,
            token_binding: token.public_id, require_session_binding: true, ttl: VerificationBase::STEP_UP_TTL,
            actor_ref: current_client.public_id, resource_ref: nil, tenant_ref: nil,
          )
        end

        def find_totp
          @totp = current_client.client_totp_credentials.find_by!(public_id: params.expect(:id))
        end

        def totp_params
          params.expect(client_totp_credential: [:title])
        end

        def index_page_props
          {
            title: t("base.shared.identity.totps.title"),
            description: t("base.shared.identity.totps.description"),
            back_link: { label: t("base.shared.identity.up_link"), href: base_app_identity_path(ri: params[:ri]) },
            new_link: {
              label: t("actions.add"),
              href: new_base_app_identity_totp_path(ri: params[:ri]),
            },
            columns: {
              title: t("activerecord.attributes.user_totp_credential.title"),
              last_otp_at: t("activerecord.attributes.user_totp_credential.last_otp_at"),
              status: t("base.shared.identity.totps.status_label"),
              actions: t("actions.actions"),
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
            title: t("base.shared.identity.totps.show_title"),
            description: t("base.shared.identity.totps.show_description"),
            back_link: { label: t("actions.back"),
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
              confirm: t("base.shared.identity.totps.remove_confirm"),
            },
            error: error,
          }
        end

        def totp_status_label(totp)
          case totp.user_identity_totp_credential_status_id
          when ClientTotpCredentialStatus::ACTIVE then t("base.shared.identity.totps.statuses.active")
          when ClientTotpCredentialStatus::INACTIVE then t("base.shared.identity.totps.statuses.inactive")
          when ClientTotpCredentialStatus::REVOKED then t("base.shared.identity.totps.statuses.revoked")
          when ClientTotpCredentialStatus::DELETED then t("base.shared.identity.totps.statuses.deleted")
          when ClientTotpCredentialStatus::NOTHING then t("base.shared.identity.totps.statuses.nothing")
          else raise ArgumentError, "unsupported TOTP credential status"
          end
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
