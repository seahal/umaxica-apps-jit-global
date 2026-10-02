# typed: false
# frozen_string_literal: true

module Palm
  module App
    module Sign
      # The native app retains its PKCE verifier. Palm binds the external browser's return
      # to the app's state; Base remains the sole OAuth/OIDC authorization and token authority.
      class InsController < Palm::App::ApplicationController
        include CommonRedirect

        AUTHENTICATION_MODE = :bare
        PENDING_FLOWS_SESSION_KEY = "palm_native_pending_flows"
        PENDING_FLOW_LIMIT = 2
        FLOW_TTL = 10.minutes
        CONTINUITY_MAX_LENGTH = 256

        public

        def show
          response.set_header("Cache-Control", "no-store")
          response.set_header("Referrer-Policy", "no-referrer")
          query = params.slice(
            :response_type, :client_id, :redirect_uri, :scope, :code_challenge,
            :code_challenge_method, :state, :nonce, :prompt, :max_age,
          ).permit(
            :response_type, :client_id, :redirect_uri, :scope, :code_challenge,
            :code_challenge_method, :state, :nonce, :prompt, :max_age,
          ).to_h.symbolize_keys
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

          flows[query.fetch(:state)] = {
            "client_id" => query.fetch(:client_id),
            "created_at" => now,
          }
          session[PENDING_FLOWS_SESSION_KEY] = flows.to_a.last(PENDING_FLOW_LIMIT).to_h
          url = ::Oidc::AcmeServiceOrigin.from(
            ENV.fetch("PUBLIC_BASE_SERVICE_URL"), default_scheme: "https",
          ).authorization_endpoint(query: query)
          redirect_to_jump_url(url, preserve_query_keys: ["redirect_uri"], status: :see_other)
        rescue ArgumentError, OidcClientRegistry::ClientNotFound, OidcClientRegistry::InvalidRedirectUri
          invalid_request
        end

        private

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
