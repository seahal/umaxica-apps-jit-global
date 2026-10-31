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
        sign_entry_classification! :excluded, reason: "not a sign entry: ticket/re-verification ceremony or sign-out"
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
          handoff =
            ClientAuthCeremonySession.writing_connection do
              ClientAuthCeremonySession.transaction do
                locked_parent = ClientOidcAuthorizationTransaction.lock.find(transaction.id)
                ceremony.with_lock do
                  BaseAuthAdmissionCoordinator.validate_switch_request!(transaction: locked_parent, target: target)
                  if sign_entry_ceremony_progressed?(ceremony)
                    raise AuthCeremonySession::InvalidTransition, "auth ceremony has progressed"
                  end

                  ceremony.cancel!
                  BaseAuthAdmissionCoordinator.issue_switch_handoff!(
                    transaction: locked_parent, ceremony_session: ceremony, target: target,
                  )
                end
              end
            end
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
