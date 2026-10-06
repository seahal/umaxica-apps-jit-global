# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Check
          module Telephone
            class PasskeysController < ::Auth::App::ApplicationController
              include CommonRedirect
              include ::PasskeyRegistrationFlow
              include SignUpSequenceControllerSupport
              include SignUpExplicitStepControllerSupport
              include ::SurfaceInertiaPage
              include AppSignUpCheckpointPage

              AUTHENTICATION_MODE = :guest

              before_action :load_sign_up_ticket
              before_action :load_sign_up_actor
              before_action :validate_sign_up_checkpoint_contact!
              before_action -> { authorize_sign_up_requirement!(:register_passkey?) }

              def show
                return unless load_gate_context!(gate_for_show)
                if @sign_up_ticket.pending_passkey_registration_id
                  return redirect_to(
                    auth_app_sign_up_check_telephone_secret_path(
                      **sign_up_flow_binding_params,
                      ri: params[:ri],
                      pt: signed_pt_param,
                    ), status: :see_other,
                  )
                end

                @sign_up_actor = sign_up_pending_actor
                @success_redirect_url = success_redirect_url
                render_sign_up_passkey_page
              end

              def create
                return unless load_gate_context!(gate_for_create)
                return head :conflict if @sign_up_ticket.pending_passkey_registration_id

                @sign_up_actor = sign_up_pending_actor
                render_passkey_registration_options
              end

              def update
                return unless load_gate_context!(gate_for_update)

                @sign_up_actor = sign_up_pending_actor
                return unless validate_sign_up_checkpoint_version!(json: true)
                if @sign_up_ticket.pending_passkey_registration_id
                  return render json: {
                    status: "ok",
                    redirect_url: auth_app_sign_up_check_telephone_secret_path(
                      **sign_up_flow_binding_params,
                      ri: params[:ri],
                      pt: signed_pt_param,
                    ),
                  }, status: :created
                end
                return unless verify_and_create_passkey_registration!

                render json: {
                  status: "ok",
                  redirect_url: auth_app_sign_up_check_telephone_secret_path(
                    **sign_up_flow_binding_params,
                    ri: params[:ri],
                    pt: signed_pt_param,
                  ),
                }, status: :created
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              # The same two endpoints the Stimulus registration controller used, and the same
              # checkpoint version the server re-validates before it clears the requirement.
              def render_sign_up_passkey_page
                path = auth_app_sign_up_check_telephone_passkey_path(
                  **sign_up_flow_binding_params, ri: params[:ri],
                                                 pt: signed_pt_param,
                )

                render inertia: "auth/app/sign/up/checkpoint/passkeys/new",
                       props: {
                         title: t("sign.app.registration.checkpoint.show.passkey.title"),
                         begin_url: path,
                         finish_url: path,
                         success_redirect_url: @success_redirect_url,
                         checkpoint_version: (
                           params[:checkpoint_version].presence || @sign_up_ticket.checkpoint_version
                         ).to_i,
                         description_label: t("sign.app.settings.passkeys.new.description_label"),
                         description_placeholder: t("sign.app.settings.passkeys.new.description_placeholder"),
                         submit_label: t("sign.app.settings.passkeys.new.submit"),
                       }
              end

              def success_redirect_url
                auth_app_sign_up_check_telephone_secret_path(
                  **sign_up_flow_binding_params, ri: params[:ri],
                                                 pt: signed_pt_param,
                )
              end

              def load_sign_up_actor
                @sign_up_actor = sign_up_pending_actor
                return if @sign_up_actor

                render json: { error: I18n.t("errors.messages.not_found") },
                       status: :not_found
              end

              def passkey_registration_actor = @sign_up_actor

              def passkey_registration_passkeys = @sign_up_actor.client_passkeys

              def save_passkey_registration!(passkey)
                @sign_up_actor.with_lock do
                  passkey.save!
                  @sign_up_ticket.update!(pending_passkey_registration_id: passkey.id)
                  ClientSecretPasskeyReservationIssuer.call_for_sign_up!(
                    flow: @sign_up_ticket, nonce: sign_up_session_state.cycle_payload.stringify_keys.fetch("nonce"),
                    passkey: passkey, expires_after: ClientSecretLifetimesValue.issuance_ttl,
                  )
                end
              end

              def sign_up_requirement_context
                SignUpRequirementContext.build(
                  surface: :app,
                  actor_authentication: sign_up_actor_authentication,
                  ticket: @sign_up_ticket,
                  requirement: :passkey,
                  pending_actor: @sign_up_actor,
                )
              rescue ArgumentError
                nil
              end

              def sign_up_family = "telephone"

              def sign_up_step = :passkey

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
