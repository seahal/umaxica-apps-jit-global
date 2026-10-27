# typed: false
# frozen_string_literal: true

# Fetch Metadata test for "the browser is navigating here". `Sec-Fetch-Mode: navigate` is set only
# by the browser and no page script can request that mode, so it carries the proof. The destination
# is `document` for a direct navigation and `empty` when this origin's service worker re-fetches the
# navigation (`fetch(event.request)` in app/views/pwa/service-worker.js). A destination that names a
# frame or another embedding context is not a top-level navigation.
module BrowserNavigationRequest
  extend ActiveSupport::Concern

  NAVIGATION_DESTINATIONS = %w(document empty).freeze

  private

  def browser_navigation_request?
    request.get? && !request.head? &&
      request.headers["Sec-Fetch-Mode"].to_s == "navigate" &&
      NAVIGATION_DESTINATIONS.include?(request.headers["Sec-Fetch-Dest"].to_s)
  end

  # A request that declares a destination other than a top-level document (for example `iframe`).
  # A missing header is not a framed destination: the caller decides (owner, 2026-10-27, D-197: the
  # Visa confirmation then renders its non-consuming form).
  def framed_destination_request?
    destination = request.headers["Sec-Fetch-Dest"]
    !destination.nil? && NAVIGATION_DESTINATIONS.exclude?(destination)
  end
end
