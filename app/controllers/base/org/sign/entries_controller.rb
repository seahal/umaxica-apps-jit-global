# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Sign
      class EntriesController < Base::Org::ApplicationController
        include ::OidcRpSignEntry

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        before_action :reject_authenticated_rp_start!
        helper_method :neutral_sign_form_url, :neutral_sign_target_link_uri

        private

        # This self-RP and its authority share one origin, and Jump refuses an rt whose url origin
        # equals its iss, so a same-origin authorize URL stays direct instead of becoming a Jump
        # handoff. Any other target keeps the shared decision.
        def oidc_redirect_decision(url)
          decision = oidc_acme_service_origin.decision_for_authorize_url(url, request: request)
          return decision if decision.direct? && request_origin_url?(url)

          super
        end
      end
    end
  end
end
