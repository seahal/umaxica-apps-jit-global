# typed: false
# frozen_string_literal: true

module Visa
  module App
    # Visa owns the browser-facing OpenID Provider surface. Bare endpoints do not
    # read or write the Base RP session and are deliberately separate from the
    # Base controller hierarchy.
    class BareController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::DefaultNoStore

      AUTHENTICATION_MODE = :bare

      prepend_before_action :apply_default_no_store

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
