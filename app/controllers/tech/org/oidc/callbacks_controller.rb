# typed: false
# frozen_string_literal: true

module Tech
  module Org
    module Oidc
      class CallbacksController < Tech::Org::ApplicationController
        include ::OidcCallback

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "tech-org-ww"
        end

        def rp_callback_access_allowed?(token_response)
          access_token, refresh_token = OidcRpBrowserCredentialContract.require_token_response!(token_response)
          return true if TechCapabilityClient.allowed?(access_token:)

          revocation = OidcOpRevocationClient.revoke(
            client_id: oidc_client_id, resource_type: rp_cell_resource_type, token: refresh_token,
          )
          log_callback_failure(
            reason: "tech_capability_denied_revocation_#{revocation.outcome}", status: :forbidden,
          )
          false
        end

        def render_rp_callback_access_denied!
          render_oidc_access_denied!
        end

        def render_oidc_access_denied!
          clear_oidc_session_state!
          response.set_header("Cache-Control", "no-store")
          render "tech/org/access_denials/show", status: :forbidden
        end
      end
    end
  end
end
