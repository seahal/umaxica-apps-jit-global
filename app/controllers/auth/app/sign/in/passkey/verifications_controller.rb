# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      module In
        module Passkey
          class VerificationsController < ::Auth::App::ApplicationController
            include ::PasskeySignInFlow
            include ::AuthenticationModeSwitchGuard
            include EmailValidation
            include IdentifierDetection

            AUTHENTICATION_MODE = :guest
            declare_authentication_mode! :guest
            before_action :start_minimum_response_budget
            after_action :enforce_minimum_response_budget

            rate_limit(
              to: 5,
              within: 1.minute,
              by: -> { request.remote_ip },
              scope: "auth_app_sign_in",
              name: "passkey_verification_ip_burst",
              store: rate_limit_store,
              with: -> {
                render_rate_limited(retry_after: 60)
              },
            )
            rate_limit(
              to: 20,
              within: 15.minutes,
              by: -> { request.remote_ip },
              scope: "auth_app_sign_in",
              name: "passkey_verification_ip_sustained",
              store: rate_limit_store,
              with: -> {
                render_rate_limited(retry_after: 900)
              },
            )

            def create = verification

            private

            def find_active_passkey_actor(identifier)
              user = find_user_by_identifier(identifier)
              user if user&.active?
            end

            def before_passkey_options_request!
              verify_turnstile_stealth!
            end

            def allow_passkey_sign_in?(passkey)
              return true if passkey.user.has_verified_pii?

              Rails.logger.info(
                JitLogEvent.format(
                  "authentication.passkey.failed",
                  reason: "verified_pii_missing",
                  user_id: passkey.user_id,
                  ip_address: request.remote_ip,
                  ri: current_region_identifier,
                ),
              )
              render_error("errors.webauthn.credential_not_found", :unauthorized)
              false
            end

            def perform_passkey_sign_in(passkey)
              pt = retrieve_pt_for_checkpoint
              AuthenticationSessionCommitter.call(
                controller: self, resource: passkey.user, pt: pt, ri: current_region_identifier, auth_method: "passkey",
              )
            end

            def handle_domain_specific_login_status(result)
              case result[:status]
              when :mfa_required
                render json: { status: "mfa_required", redirect_url: result[:redirect_path] }, status: :ok
                true
              when :session_limit_hard_reject
                render_session_limit_hard_reject(message: result[:message], http_status: result[:http_status])
                true
              else
                false
              end
            end

            def render_passkey_restricted_success(_result)
              render json: {
                status: "session_restricted",
                redirect_url: auth_app_sign_in_session_path,
                message: I18n.t("sign.app.in.session.restricted_notice"),
              }, status: :ok
            end

            def passkey_checkpoint_redirect_url
              auth_app_sign_in_check_path(
                pt: retrieve_pt_for_checkpoint,
                ri: current_region_identifier,
              )
            end

            def passkey_default_redirect_url
              base_app_identity_url(ri: current_region_identifier, host: base_authority_host)
            end
          end
        end
      end
    end
  end
end
