# typed: false
# frozen_string_literal: true

module Visa
  module Org
    class CeremonyBindingConfirmationsController < ::Visa::Org::AuthorityController
      include ::BaseCeremonyBindingConfirmation

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      class << self
        public

        def ceremony_binding_allowed_purposes
          AuthAdmissionBinding::PARENT_PURPOSES.fetch(:authorization_transaction)
        end
      end

      private

      def automatic_ceremony_binding_confirmation?
        return false unless request.get? && !request.head?

        request.headers["Sec-Fetch-Mode"].to_s == "navigate" &&
          request.headers["Sec-Fetch-Dest"].to_s == "document"
      end
    end
  end
end
