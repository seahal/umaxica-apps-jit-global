# typed: false
# frozen_string_literal: true

module Base
  module Com
    class CeremonyBindingConfirmationsController < ::Base::Com::AuthorityController
      include ::BaseCeremonyBindingConfirmation

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open
    end
  end
end
