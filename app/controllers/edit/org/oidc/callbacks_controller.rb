# typed: false
# frozen_string_literal: true

module Edit
  module Org
    module Oidc
      class CallbacksController < Edit::Org::ApplicationController
        include ::OidcCallback

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        skip_before_action :set_region, raise: false

        public

        private

        def oidc_client_id
          "edit-org-ww"
        end
      end
    end
  end
end
