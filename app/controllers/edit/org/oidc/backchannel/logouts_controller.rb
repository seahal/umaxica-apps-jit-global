# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Oidc
      module Backchannel
        class LogoutsController < ActionController::API
          include ::OidcRpLogoutReceiver
          include ::DefaultNoStore

          AUTHENTICATION_MODE = :bare

          prepend_before_action :apply_default_no_store

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
