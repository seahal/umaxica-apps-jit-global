# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      # D06 Switch between the first Sign In and Sign Up pages. Auth ends its ceremony like a Cancel
      # but keeps the parent authorization; Base issues a fresh admission for the other flow.
      class SwitchesController < ::Auth::App::ApplicationController
        include ::SignEntryExit

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        public

        def create
          ceremony = sign_entry_first_page_ceremony
          transaction = sign_entry_parent_transaction
          return refuse_sign_entry_exit!("not_on_first_page") unless ceremony && transaction

          target = params[:to]
          raise ArgumentError, "invalid switch target" unless target.is_a?(String)

          # Validate before ending the ceremony so a refused Switch leaves the user where they were.
          BaseAuthAdmissionCoordinator.validate_switch_request!(transaction:, target:)
          ceremony.cancel!
          handoff = BaseAuthAdmissionCoordinator.issue_switch_handoff!(
            transaction: transaction, ceremony_session: ceremony.reload, target: target,
          )
          redirect_to_jump_url(
            visa_app_oidc_switch_url(
              switch_handoff: handoff, ri: params[:ri], host: visa_authority_host, protocol: "https",
            ), status: :see_other,
          )
        rescue BaseAuthAdmissionCoordinator::Denied, AuthCeremonySession::InvalidTransition, ArgumentError
          refuse_sign_entry_exit!("switch_unavailable")
        end

        private

        def sign_entry_exit_sign_up_cycle_class = ClientSignUpFlow
      end
    end
  end
end
