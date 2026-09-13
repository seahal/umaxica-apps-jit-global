# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Check
          module Telephone
            class PasscodesController < ::Auth::App::ApplicationController
              include CommonRedirect
              include SignPasscodeRegistrationFlow
              include SignUpSequenceControllerSupport
              include SignUpExplicitStepControllerSupport
              include ::SurfaceInertiaPage
              include AppSignUpCheckpointPage
              # `show` and the failed-submit re-render of `update` both put the plaintext recovery
              # secret in the `secret` prop, which inertia_rails serializes into the document. The
              # checkpoint concern sets `no-store` only on its age-restricted branch, so without
              # this the reveal itself was cacheable and Back could resurrect the plaintext.
              include ::SignSettingsSecretCredentialCacheControl

              AUTHENTICATION_MODE = :guest

              before_action :set_no_store_for_secret_credential_pages
              before_action :load_sign_up_ticket
              before_action :load_sign_up_actor
              before_action :validate_sign_up_checkpoint_contact!
              before_action -> { authorize_sign_up_requirement!(:confirm_passcode?) }

              def show
                return unless load_gate_context!(gate_for_show)

                @sign_up_actor = sign_up_pending_actor
                prepare_passcode_registration
                render_sign_up_passcode_page
              end

              def update
                return unless load_gate_context!(gate_for_update)

                @sign_up_actor = sign_up_pending_actor
                return unless validate_sign_up_checkpoint_version!

                create_passcode_registration!
                result = perform_sign_up_event(
                  :clear_requirement,
                  payload: { requirement: :passcode, checkpoint_version: sign_up_checkpoint_version_param },
                )
                return finalize_sign_up_from_checkpoint! if result.success? && result.next_event == :finalize
                return render_sign_up_result(result) unless result.success?

                redirect_to(auth_app_sign_up_check_telephone_birthdate_path(ri: params[:ri], pt: signed_pt_param))
              rescue ActiveRecord::RecordInvalid => e
                @secret_credential = e.record
                @raw_secret_credential = session[passcode_registration_raw_session_key]
                render_sign_up_passcode_page(status: :unprocessable_content)
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              # The generated passcode is the content of this page: it is displayed exactly once,
              # which is what the template did. Nothing else about the credential crosses.
              def render_sign_up_passcode_page(status: :ok)
                scope = "sign.app.registration.checkpoint.show.passcode"

                render inertia: "auth/app/sign/up/checkpoint/passcodes/new",
                       props: {
                         title: page_t("#{scope}.title"),
                         description: page_t("#{scope}.description"),
                         action: auth_app_sign_up_check_telephone_passcode_path(
                           ri: params[:ri],
                           pt: signed_pt_param,
                         ),
                         scope: "user_secret_credential",
                         checkpoint_version: (
                           params[:checkpoint_version].presence || @sign_up_ticket.checkpoint_version
                         ).to_i,
                         errors: @secret_credential&.errors&.full_messages || [],
                         name_label: ClientSecretCredential.human_attribute_name(:name),
                         secret_heading: "Secret",
                         secret: @raw_secret_credential.to_s,
                         one_time_notice: t("views.sign.app.settings.secret_credentials.new.one_time_notice"),
                         save_label: t("actions.save"),
                         cancel_label: t("actions.cancel"),
                       },
                       status: status
              end

              def load_sign_up_actor
                @sign_up_actor = sign_up_pending_actor
                return if @sign_up_actor

                render plain: I18n.t("errors.messages.not_found"), status: :not_found
              end

              def passcode_registration_secret_credentials = @sign_up_actor.client_secret_credentials

              def passcode_registration_secret_credential_class = ClientSecretCredential

              def passcode_registration_raw_session_key = :auth_app_up_passcode_raw

              def passcode_registration_param_key = :user_secret_credential

              def passcode_registration_fallback_param_key = :client_secret

              def passcode_registration_create_secret_credential!(raw_secret_credential)
                secret_credential = @sign_up_actor.client_secret_credentials.new(
                  passcode_registration_secret_credential_params.merge(
                    password: raw_secret_credential,
                    raw_secret_credential: raw_secret_credential,
                    user_identity_secret_status_id: ClientSecretCredentialStatus::ACTIVE,
                    user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
                  ),
                )
                # save! with validate: false bypasses validators while preserving
                # creation callbacks for system-generated sign-up credentials.
                secret_credential.save!(validate: false)
                secret_credential
              end

              def sign_up_requirement_context
                SignUpRequirementContext.build(
                  surface: :app,
                  actor_authentication: sign_up_actor_authentication,
                  ticket: @sign_up_ticket,
                  requirement: :passcode,
                  pending_actor: @sign_up_actor,
                )
              rescue ArgumentError
                nil
              end

              def sign_up_family = "telephone"

              def sign_up_step = :passcode

              def sign_up_surface = :app

              def sign_up_ticket_class = ClientSignUpFlow

              def sign_up_sequence_session_key = :auth_app_up_sequence_id
            end
          end
        end
      end
    end
  end
end
