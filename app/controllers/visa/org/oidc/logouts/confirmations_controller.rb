# typed: false
# frozen_string_literal: true

module Visa
  module Org
    module Oidc
      module Logouts
        class ConfirmationsController < ::Visa::Org::Oidc::LogoutsController
          AUTHENTICATION_MODE = :open

          declare_authentication_mode! :open

          public

          def create
            confirm_oidc_end_session_logout
          end
        end
      end
    end
  end
end
