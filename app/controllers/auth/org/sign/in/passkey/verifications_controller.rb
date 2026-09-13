# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        module Passkey
          # POST /sign/in/passkey/verification
          #
          # Second stage of Normal org sign-in. Requires the pending Entra
          # transaction; see SignOrgNormalPasskeyCeremony.
          class VerificationsController < ::Auth::Org::ApplicationController
            include ::SignOrgNormalPasskeyCeremony

            AUTHENTICATION_MODE = :guest

            def create = verification
          end
        end
      end
    end
  end
end
