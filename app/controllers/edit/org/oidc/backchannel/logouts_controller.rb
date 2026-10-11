# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Oidc
      module Backchannel
        class LogoutsController < ActionController::API
          include ::OidcRpLogoutReceiver

          AUTHENTICATION_MODE = :bare

          public

          def create
            handle_oidc_backchannel_logout
          end

          private

          def oidc_client_id
            "edit-org"
          end
        end
      end
    end
  end
end
