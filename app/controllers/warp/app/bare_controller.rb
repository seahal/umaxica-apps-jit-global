# typed: false
# frozen_string_literal: true

module Warp
  module App
    # Intentionally bypasses ApplicationController and its app-wide callbacks.
    # Do not normalize this inheritance; bare endpoints own only the callbacks declared here.
    class BareController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit

      AUTHENTICATION_MODE = :bare

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
