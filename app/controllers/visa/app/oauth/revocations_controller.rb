# typed: false
# frozen_string_literal: true

module Visa
  module App
    module Oauth
      class RevocationsController < ActionController::API
        include ActionController::MimeResponds
        include ::RateLimit
        include ::FqdnAvailabilityGate
        include ::DefaultNoStore
        include BaseOauthEndpoint
        include BaseOauthRevocationEndpoint

        private :respond_to

        AUTHENTICATION_MODE = :open
        OIDC_RESOURCE_TYPE = "client"

        prepend_before_action :apply_default_no_store
        before_action :skip_oauth_session!
        before_action :set_oauth_cache_headers
        after_action :set_oauth_cache_headers
        rate_limit(
          to: 20,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "visa_app_oauth_revoke",
          name: "revocation_ip",
          store: rate_limit_store,
          only: :create,
          with: -> {
            render_rate_limited(retry_after: 60)
          },
        )
        before_action -> { prepare_revocation_request!(resource_type: OIDC_RESOURCE_TYPE) }, only: :create
        rate_limit(
          to: 600,
          within: 1.minute,
          by: -> { authenticated_revocation_client_id },
          scope: "visa_app_oauth_revoke",
          name: "revocation_client",
          store: rate_limit_store,
          only: :create,
          if: -> { authenticated_revocation_client? },
          with: -> {
            render_rate_limited(retry_after: 60)
          },
        )

        rescue_from BaseOauthRevocationEndpoint::InvalidRequest,
                    ActionController::BadRequest,
                    ActionDispatch::Http::Parameters::ParseError,
                    with: :render_revocation_invalid_request
        rescue_from ActiveRecord::ActiveRecordError, PG::Error,
                    with: :render_revocation_dependency_failure

        public

        def create
          revoke
        end

        private

        def revoke
          result = @revoker.call
          render_revocation_result(result)
        end
      end
    end
  end
end
