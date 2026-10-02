# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Sign
      # The native app retains its PKCE verifier. Palm binds the external browser's return
      # to the app's state; Base remains the sole OAuth/OIDC authorization and token authority.
      #
      # Palm shares the neutral `GET /sign` page and CSRF-protected `POST /sign` starter with the
      # other first-party RPs. The native request parameters arrive on the GET and travel to the
      # POST as form fields, so no browser state exists until the POST starts the flow.
      class EntriesController < Palm::App::ApplicationController
        include CommonRedirect

        AUTHENTICATION_MODE = :bare
        PENDING_FLOWS_SESSION_KEY = "palm_native_pending_flows"
        PENDING_FLOW_LIMIT = 2
        FLOW_TTL = 10.minutes
        CONTINUITY_MAX_LENGTH = 256
        NATIVE_REQUEST_KEYS = %i(
          response_type client_id redirect_uri scope code_challenge
          code_challenge_method state nonce prompt max_age
        ).freeze

        public

        def show
          response.set_header("Cache-Control", "no-store")
          response.set_header("Referrer-Policy", "no-referrer")
          query = native_request_query
          return invalid_request unless valid_native_request?(query)

          OidcAuthorizeRequestResolver.new(params: query, resource: nil, resource_type: "client").call
          @native_request = query.compact
          render layout: false
        rescue ArgumentError, OidcClientRegistry::ClientNotFound, OidcClientRegistry::InvalidRedirectUri
          invalid_request
        end

        def create
          response.set_header("Cache-Control", "no-store")
          response.set_header("Referrer-Policy", "no-referrer")
          query = native_request_query
          return invalid_request unless valid_native_request?(query)

          validated = OidcAuthorizeRequestResolver.new(params: query, resource: nil, resource_type: "client").call
          query[:scope] = validated.scope
          query[:ri] = current_region_identifier
          now = Time.current.to_i
          flows =
            session[PENDING_FLOWS_SESSION_KEY].to_h.select do |_state, flow|
              flow.fetch("created_at") <= now && now < flow.fetch("created_at") + FLOW_TTL.to_i
            end
          return invalid_request if flows.key?(query.fetch(:state))
          # At the limit the new flow is refused and the live ones are kept: evicting the oldest
          # would silently break an app that is still waiting on it.
          return invalid_request if flows.size >= PENDING_FLOW_LIMIT

          flows[query.fetch(:state)] = {
            "client_id" => query.fetch(:client_id),
            "created_at" => now,
          }
          session[PENDING_FLOWS_SESSION_KEY] = flows
          url = ::Oidc::AcmeServiceOrigin.from(
            ENV.fetch("PUBLIC_BASE_SERVICE_URL"), default_scheme: "https",
          ).authorization_endpoint(query: query)
          redirect_to_jump_url(url, preserve_query_keys: ["redirect_uri"], status: :see_other)
        rescue ArgumentError, OidcClientRegistry::ClientNotFound, OidcClientRegistry::InvalidRedirectUri
          invalid_request
        end

        private

        def native_request_query
          params.slice(*NATIVE_REQUEST_KEYS).permit(*NATIVE_REQUEST_KEYS).to_h.symbolize_keys
        end

        def valid_native_request?(query)
          return false unless OidcClientStoresStaticClientStore::NATIVE_COMPLETION_URIS.key?(query[:client_id])
          return false if params.key?(:code_verifier)
          return false unless query[:code_challenge].is_a?(String) && query[:code_challenge].match?(/\A[A-Za-z0-9_-]{43}\z/)

          %i(state nonce).all? do |key|
            query[key].is_a?(String) && query[key].bytesize.between?(1, CONTINUITY_MAX_LENGTH)
          end
        end

        def invalid_request
          render plain: I18n.t("errors.messages.invalid_request"), status: :bad_request
        end
      end
    end
  end
end
