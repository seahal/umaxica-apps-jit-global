# typed: false
# frozen_string_literal: true

module Base
  module Dev
    class ApplicationController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::DefaultNoStore

      include ::Session

      include ::ActorSupport

      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      prepend_before_action :apply_default_no_store

      helper_method :current_actor
      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays a side-effect-free helper; the limit and its numeric
      # value are declared here on the inheriting controller.
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "base_dev_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )
      before_action :set_current_context
      before_action :reset_flash
      prepend_around_action :with_actor_lifecycle

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
