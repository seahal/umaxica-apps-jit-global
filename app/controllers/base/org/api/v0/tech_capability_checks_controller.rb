# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        # POST /api/v0/tech-capability-checks (R5-WU11). Answers {"allowed": true|false} for the Tech
        # RP from current org-authority state; no browser session or cookie takes part.
        class TechCapabilityChecksController < ActionController::API
          include ::DefaultNoStore

          prepend_before_action :apply_default_no_store
          include ::RateLimit

          AUTHENTICATION_MODE = :open

          rate_limit(
            to: 120, within: 1.minute, by: -> { request.remote_ip }, scope: "base_org_tech_capability_check",
            name: "tech_capability_check_ip", store: rate_limit_store, only: :create,
            with: -> { head :too_many_requests },
          )

          public

          def create
            allowed = TechCapabilityCheckQuery.call(
              access_token: params[:access_token].to_s, client_assertion: params[:client_assertion].to_s,
              endpoint_uri: request.original_url, host: request.host,
            )
            response.headers["Cache-Control"] = "no-store"
            render json: { allowed: }, status: :ok
          end
        end
      end
    end
  end
end
