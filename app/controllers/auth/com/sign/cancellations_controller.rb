# typed: false
# frozen_string_literal: true

module Auth
  module Com
    module Sign
      # D09 Cancel from the first Sign In or Sign Up page. Auth ends its ceremony and hands Base a
      # single-use cancellation; Base commits it and returns access_denied to the RP.
      class CancellationsController < ::Auth::Com::ApplicationController
        include ::SignEntryExit

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        public

        def create
          ceremony = sign_entry_first_page_ceremony
          transaction = sign_entry_parent_transaction
          return refuse_sign_entry_exit!("not_on_first_page") unless ceremony && transaction

          issuance = BaseAuthAdmissionCoordinator.issue_cancellation!(
            transaction: transaction, ceremony_session_ref: ceremony.id.to_s,
          )
          ceremony.cancel!
          redirect_to_jump_url(
            visa_com_oidc_cancellation_url(
              cancellation_ref: issuance.reference, transaction_ref: transaction.transaction_id, ri: params[:ri],
              host: visa_authority_host, protocol: "https",
            ), status: :see_other,
          )
        rescue BaseAuthAdmissionCoordinator::Denied, AuthCeremonySession::InvalidTransition, ArgumentError
          refuse_sign_entry_exit!("cancellation_unavailable")
        rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
          render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
        end

        private

        def sign_entry_exit_sign_up_cycle_class = VisitorSignUpFlow
      end
    end
  end
end
