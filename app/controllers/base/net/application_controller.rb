# typed: false
# frozen_string_literal: true

module Base
  module Net
    # An OIDC/OAuth Non-Participant face: it has no actor, session, or preference lifecycle.
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::DefaultNoStore

      AUTHENTICATION_MODE = :deny_all

      prepend_before_action :apply_default_no_store

      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays an effect-free helper; the limit and its numeric
      # value are declared here on the inheriting controller.
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "base_net_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
