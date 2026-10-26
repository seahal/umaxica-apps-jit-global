# typed: false
# frozen_string_literal: true

module Visa
  module Com
    module Oidc
      module Logouts
        class ConfirmationsController < ::Visa::Com::Oidc::LogoutsController
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
