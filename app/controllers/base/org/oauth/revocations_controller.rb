# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Oauth
      class RevocationsController < Base::Org::BareController
        include BaseOauthEndpoint

        AUTHENTICATION_MODE = :open
        OIDC_RESOURCE_TYPE = "operator"

        before_action :skip_oauth_session!
        after_action :set_oauth_cache_headers
        # The 401/200 distinction on an invalid client_secret is a guessing oracle;
        # this endpoint is the only OAuth POST that had no limiter.
        rate_limit(
          to: 20,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "base_org_oauth_revoke",
          name: "revocation_ip",
          store: rate_limit_store,
          only: :create,
          with: -> {
            render_rate_limited(retry_after: 60)
          },
        )

        def create
          result = ::OidcTokenRevoker.call(
            token: params[:token],
            client_id: params[:client_id],
            client_secret: params[:client_secret],
            token_type_hint: params[:token_type_hint],
            host: request.host,
            expected_resource_type: OIDC_RESOURCE_TYPE,
          )
          return head :ok if result.success?

          render json: { error: result.error, error_description: result.error_description },
                 status: :unauthorized
        end
      end
    end
  end
end
