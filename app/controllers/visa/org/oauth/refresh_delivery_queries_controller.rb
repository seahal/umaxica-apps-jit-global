# typed: false
# frozen_string_literal: true

module Visa
  module Org
    module Oauth
      # R5-WU08 read-only Refresh delivery recovery for this realm's OP.
      class RefreshDeliveryQueriesController < ActionController::API
        include ActionController::MimeResponds
        include ::RateLimit
        include ::FqdnAvailabilityGate
        include ::DefaultNoStore
        include BaseOauthEndpoint
        include BaseOauthRefreshDeliveryQueryEndpoint

        AUTHENTICATION_MODE = :open
        OIDC_RESOURCE_TYPE = "operator"

        prepend_before_action :apply_default_no_store
        before_action :skip_oauth_session!
        after_action :set_oauth_cache_headers
        rate_limit(
          to: 10,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "visa_org_oauth_refresh_delivery_query",
          name: "refresh_delivery_query_ip",
          store: rate_limit_store,
          only: :create,
          with: -> {
            render_rate_limited(retry_after: 60)
          },
        )
      end
    end
  end
end
