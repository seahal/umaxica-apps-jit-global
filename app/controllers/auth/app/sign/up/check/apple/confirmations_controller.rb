# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module Up
        module Check
          module Apple
            class ConfirmationsController < ::Auth::App::ApplicationController
              include SignUpExplicitStepControllerSupport
              include SignUpSocialPendingClientSupport
              include ::SurfaceInertiaPage
              include ::TurnstilePageProps

              AUTHENTICATION_MODE = :open

              def show
                return unless load_gate_context!(gate_for_show)

                render_social_signup_confirmation_page
              end

              def update
                return unless load_gate_context!(gate_for_update)
                return render plain: "social_signup_confirmation_required", status: :unprocessable_content unless
                  ActiveModel::Type::Boolean.new.cast(params[:confirm_new_social_identity])
                return render_turnstile_failure unless verify_social_signup_turnstile!

                bind_social_pending_client!
                clear_current_requirement!
              rescue IdentitySocialCeremonyContract::Error
                render plain: I18n.t("errors.social_auth.provider_error"), status: :unprocessable_content
              end

              def destroy
                cancel_from_explicit_step
              end

              private

              # The Turnstile challenge is bound to this ceremony: the action and the ticket's
              # public id travel as the widget's action and cdata, and `verify_social_signup_turnstile!`
              # demands the same pair back. Only the public site key crosses.
              def render_social_signup_confirmation_page
                scope = "sign.app.registration.checkpoint.show.social"

                render inertia: "auth/app/sign/up/check/social/confirmations/show",
                       props: {
                         title: page_t("#{scope}.confirm_title"),
                         unregistered: page_t(
                           "#{scope}.unregistered",
                           provider: @sign_up_ticket.social_provider.to_s.titleize,
                         ),
                         create_identity: page_t("#{scope}.create_identity"),
                         no_merge: page_t("#{scope}.no_merge"),
                         cancel_if_wrong: page_t("#{scope}.cancel_if_wrong"),
                         confirm_label: page_t("#{scope}.confirm_label"),
                         submit_label: t("actions.continue"),
                         cancel_label: t("actions.cancel"),
                         action: sign_up_confirmation_action_path,
                         checkpoint_version: @sign_up_ticket.checkpoint_version.to_i,
                         turnstile: turnstile_visible_props(
                           action: "social_signup_confirmation",
                           cdata: @sign_up_ticket.public_id,
                         ),
                       }
              end

              # The template posts back to `request.path`. The flow binding and the signed target ride
              # in the query so the step gate can tell which flow the page was served for (an unbound
              # update is refused as `flow_binding`) and neither becomes a separate prop.
              def sign_up_confirmation_action_path
                query = sign_up_flow_binding_params
                pt = signed_pt_param
                query = query.merge(pt: pt) if pt.present?
                return request.path if query.empty?

                "#{request.path}?#{query.to_query}"
              end

              def sign_up_surface = :app

              def sign_up_ticket_class = ClientSignUpFlow

              def sign_up_sequence_session_key = :auth_app_up_sequence_id

              def sign_up_family = "apple"

              def sign_up_step = :confirmation

              def verify_social_signup_turnstile!
                result =
                  Turnstile::VerifierFactory.current.verify_for_ceremony(
                    token: request.request_parameters["cf-turnstile-response"].to_s,
                    remote_ip: request.remote_ip,
                    ceremony_id: @sign_up_ticket.public_id,
                    expected_action: "social_signup_confirmation",
                    expected_hostname: request.host,
                    expected_cdata: @sign_up_ticket.public_id,
                    mode: :visible,
                  )
                log_social_signup_turnstile_failure(result) unless result["success"]
                result["success"]
              end

              def render_turnstile_failure
                render plain: I18n.t("turnstile_error"), status: :unprocessable_content
              end

              def log_social_signup_turnstile_failure(result)
                Rails.logger.info(
                  JitLogEvent.format(
                    "sign_up.social_confirmation.turnstile_failed",
                    provider: sign_up_family,
                    host: request.host,
                    flow_id_present: @sign_up_ticket&.public_id.present?,
                    token_present: request.request_parameters["cf-turnstile-response"].present?,
                    error: result["error"],
                    error_codes: result["error-codes"],
                    action: result["action"],
                    hostname: result["hostname"],
                    cdata_present: result["cdata"].present?,
                  ),
                )
              end
            end
          end
        end
      end
    end
  end
end
