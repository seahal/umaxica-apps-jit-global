# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      module Withdrawal
        # Withdrawal ceremony session lifecycle: re-entry via email OTP
        # (new/create, see WithdrawalCeremonyReentry) and ceremony sign-out
        # (destroy).
        class SessionsController < ::Base::Com::ApplicationController
          include ::SurfaceInertiaPage
          include CommonRedirect
          include WithdrawalCeremonyReentry

          AUTHENTICATION_MODE = :open
          declare_authentication_mode! :open

          rate_limit(
            to: 5,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "base_com_withdrawal_reentry",
            name: "email_create_ip_burst",
            store: rate_limit_store,
            only: :create,
            with: -> {
              render_rate_limited(retry_after: 60)
            },
          )

          # GET /identity/withdrawal/session/new
          # WithdrawalCeremonyReentry#new only assigns the screen state and relies on an implicit
          # render, so this surface makes the Inertia render explicit.
          def new
            super
            render_withdrawal_reentry_new
          end

          # DELETE /identity/withdrawal/session
          # Ends the current withdrawal ceremony and returns to the sign-in surface.
          def destroy
            revoke_current_withdrawal_ceremony!
            safe_redirect_to(
              withdrawal_public_fallback_path,
              fallback: new_base_com_identity_withdrawal_path(ri: params[:ri]),
              status: :see_other,
            )
          end

          private

          # Overrides the shared re-entry transport seam: this surface answers with an Inertia page.
          def render_withdrawal_reentry_new(status: :ok)
            render inertia: "base/com/identity/withdrawal/sessions/new",
                   props: new_page_props,
                   status: status
          end

          def new_page_props
            {
              title: "Withdrawal session",
              generic_message: withdrawal_reentry_generic_message,
              address_form: {
                url: base_com_identity_withdrawal_session_path(ri: params[:ri]),
                scope: "withdrawal_reentry",
                field: "address",
                label: "Email address",
                value: params.dig(:withdrawal_reentry, :address).to_s,
                submit_label: "Send verification code",
              },
              pass_code_form: pass_code_form_props,
            }
          end

          # The code form only appears once a code has been issued, which is what `@reentry_state`
          # records. Omitting it keeps that decision on the server.
          def pass_code_form_props
            return if @reentry_state.blank?

            {
              url: base_com_identity_withdrawal_session_path(ri: params[:ri]),
              field: "pass_code",
              label: "Verification code",
              submit_label: "Continue",
            }
          end

          def identity_email_model = VisitorEmail

          def withdrawal_email_ceremony_model = VisitorEmailCeremonyTransaction

          def withdrawal_subject_from_email(email) = email&.visitor

          def withdrawal_reentry_surface = :com

          def withdrawal_ceremony_class = VisitorWithdrawalCeremony

          def withdrawal_new_path(extra_params = {})
            new_base_com_identity_withdrawal_session_path({ ri: params[:ri] }.merge(extra_params))
          end

          def withdrawal_edit_path = edit_base_com_identity_withdrawal_path(ri: params[:ri])

          def withdrawal_public_fallback_path = auth_com_sign_in_path
        end
      end
    end
  end
end
