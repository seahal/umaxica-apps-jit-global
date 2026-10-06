# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Oauth
      class UserinfosController < Base::Com::BareController
        include BaseOauthEndpoint

        AUTHENTICATION_MODE = :open

        before_action :skip_oauth_session!
        after_action :set_oauth_cache_headers
        # Bearer-token probing against a resource endpoint must be bounded, as it
        # already is on the token endpoint.
        rate_limit(
          to: 60,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "base_com_oauth_userinfo",
          name: "userinfo_ip",
          store: rate_limit_store,
          only: %i(show create),
          with: -> {
            render_rate_limited(retry_after: 60)
          },
        )

        def show
          render_oauth_userinfo(resource_type: "visitor")
        end

        def create
          render_oauth_userinfo(resource_type: "visitor")
        end
      end
    end
  end
end
