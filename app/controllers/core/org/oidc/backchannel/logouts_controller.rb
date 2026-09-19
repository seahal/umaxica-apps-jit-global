# typed: false
# frozen_string_literal: true

module Core
  module Org
    module Oidc
      module Backchannel
        class LogoutsController < ActionController::API
          include ::OidcRpLogoutReceiver

          AUTHENTICATION_MODE = :bare

          def create
            handle_oidc_backchannel_logout
          end

          private

          def oidc_client_id
            "core-org"
          end
        end
      end
    end
  end
end
