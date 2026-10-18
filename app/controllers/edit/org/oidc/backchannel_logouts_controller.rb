# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Oidc
      # R5-WU10 back-channel logout receiver for the rp_edit_org cell.
      class BackchannelLogoutsController < ActionController::API
        include ::DefaultNoStore

        prepend_before_action :apply_default_no_store
        include RpBackchannelLogoutEndpoint

        AUTHENTICATION_MODE = :open
        RP_CELL_CONNECTION = "rp_edit_org"
      end
    end
  end
end
