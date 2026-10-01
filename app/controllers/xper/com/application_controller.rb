# typed: false
# frozen_string_literal: true

module Xper
  module Com
    # Phase 0 landing pages have no authentication, session, or preference lifecycle.
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit

      AUTHENTICATION_MODE = :bare

      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "xper_com_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )

      protect_from_forgery using: :header_or_legacy_token, with: :exception
      layout "xper/com/application"
    end
  end
end
