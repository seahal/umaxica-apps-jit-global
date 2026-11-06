# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Oidc
      class CallbacksController < Base::Org::ApplicationController
        include ::OidcCallback

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        skip_before_action :set_region, raise: false

        private

        def consume_oidc_pt
          destination = super
          (destination == "/") ? base_org_dashboard_path(ri: params[:ri]) : destination
        end

        def oidc_client_id
          "base-org-ww"
        end
      end
    end
  end
end
