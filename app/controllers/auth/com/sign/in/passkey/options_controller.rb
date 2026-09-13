# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      module In
        module Passkey
          class OptionsController < ::Auth::Com::ApplicationController
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
              scope: "auth_com_sign_in",
              name: "passkey_options_ip_burst",
              store: rate_limit_store,
              with: -> { render_rate_limited(retry_after: 60) },
            )
            rate_limit(
              to: 20,
              within: 15.minutes,
              by: -> { request.remote_ip },
              scope: "auth_com_sign_in",
              name: "passkey_options_ip_sustained",
              store: rate_limit_store,
              with: -> {
                render_rate_limited(retry_after: 900)
              },
            )

            def create = options

            private

            def identity_email_model
              VisitorEmail
            end

            def identity_telephone_model
              VisitorTelephone
            end

            def identity_from_email_record(record)
              record&.visitor
            end

            def identity_from_telephone_record(record)
              record&.visitor
            end

            def find_active_passkey_actor(identifier)
              visitor = find_user_by_identifier(identifier)
              visitor if visitor&.active?
            end

            def allow_passkey_sign_in?(passkey)
              return true if passkey.visitor.has_verified_pii?

              Rails.logger.info(
                JitLogEvent.format(
                  "authentication.passkey.failed",
                  reason: "verified_pii_missing",
                  visitor_id: passkey.visitor_id,
                  ip_address: request.remote_ip,
                  ri: current_region_identifier,
                ),
              )
              render_error("errors.webauthn.credential_not_found", :unauthorized)
              false
            end

            def perform_passkey_sign_in(passkey)
              pt = retrieve_pt_for_checkpoint
              establish_signed_in_session!(
                passkey.visitor, pt: pt, ri: current_region_identifier, auth_method: "passkey",
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
                redirect_url: auth_com_sign_in_session_path,
                message: I18n.t("sign.app.in.session.restricted_notice"),
              }, status: :ok
            end

            def passkey_checkpoint_redirect_url
              auth_com_sign_in_check_path(
                pt: retrieve_pt_for_checkpoint,
                ri: current_region_identifier,
              )
            end

            def passkey_default_redirect_url
              base_com_identity_url(ri: current_region_identifier, host: base_authority_host)
            end
          end
        end
      end
    end
  end
end
