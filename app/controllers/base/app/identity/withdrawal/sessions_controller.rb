# typed: false
# frozen_string_literal: true

module Base
  module App
    module Identity
      module Withdrawal
        # Withdrawal ceremony session lifecycle: re-entry via email OTP
        # (new/create, see WithdrawalCeremonyReentry) and ceremony sign-out
        # (destroy).
        class SessionsController < ::Base::App::Identity::BaseController
          include ::SurfaceInertiaPage
          include CommonRedirect
          include WithdrawalCeremonyReentry

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          rate_limit(
            to: 5,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "base_app_withdrawal_reentry",
            name: "email_create_ip_burst",
            store: rate_limit_store,
            only: :create,
            with: -> {
              render_rate_limited(retry_after: 60)
            },
          )

          # DELETE /identity/withdrawal/session
          # Ends the current withdrawal ceremony and returns to the sign-in surface.
          def destroy
            revoke_current_withdrawal_ceremony!
            safe_redirect_to(
              withdrawal_public_fallback_path,
              fallback: new_base_app_identity_withdrawal_path(ri: params[:ri]),
              status: :see_other,
            )
          end

          private

          def render_withdrawal_reentry_new(status: :ok)
            render inertia: "base/app/identity/withdrawal/sessions/new",
                   props: withdrawal_session_new_props,
                   status: status
          end

          def withdrawal_session_new_props
            {
              title: "Withdrawal session",
              description: withdrawal_reentry_generic_message,
              address_form: {
                action: base_app_identity_withdrawal_session_path(ri: params[:ri]),
                label: "Email address",
                address: params.dig(:withdrawal_reentry, :address).to_s,
                submit_label: "Send verification code",
              },
              pass_code_form: @reentry_state.present? ? {
                action: base_app_identity_withdrawal_session_path(ri: params[:ri]),
                label: "Verification code",
                submit_label: "Continue",
              } : nil,
            }
          end

          def identity_email_model = ClientEmail

          def withdrawal_email_ceremony_model = ClientEmailCeremonyTransaction

          def withdrawal_subject_from_email(email) = email&.user

          def withdrawal_reentry_surface = :app

          def withdrawal_ceremony_class = ClientWithdrawalCeremony

          def withdrawal_new_path(extra_params = {})
            new_base_app_identity_withdrawal_session_path({ ri: params[:ri] }.merge(extra_params))
          end

          def withdrawal_edit_path = edit_base_app_identity_withdrawal_path(ri: params[:ri])

          def withdrawal_public_fallback_path = auth_app_sign_in_path
        end
      end
    end
  end
end
