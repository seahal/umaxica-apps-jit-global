# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      # D09 Cancel from the current admitted Auth ceremony. Auth ends local continuity and hands
      # Base a single-use cancellation; Base commits it and returns access_denied to the RP.
      class CancellationsController < ::Auth::Org::ApplicationController
        include ::SignEntryExit

        AUTHENTICATION_MODE = :open
        sign_entry_classification! :excluded, reason: "not a sign entry: ticket/re-verification ceremony or sign-out"
        declare_authentication_mode! :open

        public

        def create
          ceremony, transaction = sign_entry_parent_cancellation
          return refuse_sign_entry_exit!("not_on_first_page") unless ceremony && transaction

          issuance = commit_sign_entry_parent_cancellation!(ceremony:, transaction:)
          delete_auth_ceremony_sid_cookie!
          reset_session
          redirect_to_jump_url(
            visa_org_oidc_cancellation_url(
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

        # Org has no public Sign Up, so there is no sign-up cycle to check.
        def sign_entry_exit_sign_up_cycle_class = nil
      end
    end
  end
end
