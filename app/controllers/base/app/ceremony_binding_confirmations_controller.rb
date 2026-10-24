# typed: false
# frozen_string_literal: true

module Base
  module App
    class CeremonyBindingConfirmationsController < ::Base::App::AuthorityController
      include ::BaseCeremonyBindingConfirmation

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      class << self
        public

        def ceremony_binding_allowed_purposes
          AuthAdmissionBinding::PARENT_PURPOSES.fetch(:step_up_ceremony_transaction)
        end
      end
    end
  end
end
