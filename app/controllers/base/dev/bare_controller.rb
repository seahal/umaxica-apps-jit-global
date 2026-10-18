# typed: false
# frozen_string_literal: true

module Base
  module Dev
    # Intentionally bypasses ApplicationController and its app-wide callbacks.
    # Do not normalize this inheritance; bare endpoints own only the callbacks declared here.
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
