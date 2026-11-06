# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      # D09 Cancel from the current admitted Auth ceremony. Auth ends local continuity and hands
      # Base a single-use cancellation; Base commits it and returns access_denied to the RP.
      class CancellationsController < ::Auth::App::ApplicationController
        include ::SignEntryExit

        AUTHENTICATION_MODE = :open
        sign_entry_classification! :excluded, reason: "not a sign entry: ticket/re-verification ceremony or sign-out"
        declare_authentication_mode! :open

        public

        def create
          ceremony, transaction = sign_entry_parent_cancellation
          return refuse_sign_entry_exit!("not_on_first_page") unless ceremony && transaction

          redirect_to_sign_entry_parent_cancellation!(ceremony:, transaction:)
        rescue BaseAuthAdmissionCoordinator::Denied, AuthCeremonySession::InvalidTransition, ArgumentError
          refuse_sign_entry_exit!("cancellation_unavailable")
        rescue Umaxica::Valkey::Unavailable, Umaxica::Valkey::OperationError
          render plain: I18n.t("errors.rate_limit.backend_unavailable"), status: :service_unavailable
        end

        private

        def sign_entry_exit_sign_up_cycle_class = ClientSignUpFlow
      end
    end
  end
end
