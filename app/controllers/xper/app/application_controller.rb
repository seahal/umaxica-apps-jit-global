# typed: false
# frozen_string_literal: true

module Xper
  module App
    # Phase 0 landing pages have no authentication, session, or preference lifecycle.
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::DefaultNoStore

      AUTHENTICATION_MODE = :bare

      prepend_before_action :apply_default_no_store

      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "xper_app_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )

      protect_from_forgery using: :header_or_legacy_token, with: :exception
      layout "xper/app/application"
    end
  end
end
