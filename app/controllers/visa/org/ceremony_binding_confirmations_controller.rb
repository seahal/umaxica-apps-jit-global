# typed: false
# frozen_string_literal: true

module Visa
  module Org
    class CeremonyBindingConfirmationsController < ::Visa::Org::AuthorityController
      include ::BaseCeremonyBindingConfirmation

      REJECT_FRAMED_CONFIRMATION = true
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
        browser_navigation_request?
      end
    end
  end
end
