# typed: false
# frozen_string_literal: true

module Visa
  module Org
    class AuthorityController < ::Base::Org::AuthorityController
      AUTHENTICATION_MODE = :deny_all

      # Visa is the protocol authority. Base owns operator re-verification and passkey-management
      # pages, so an OP request must not be redirected into that RP-side browser workflow.
      skip_before_action :enforce_second_passkey_gate!
    end
  end
end
