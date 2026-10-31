# typed: false
# frozen_string_literal: true

module Auth
  module Org
    # Intentionally bypasses ApplicationController and its app-wide callbacks.
    # Do not normalize this inheritance; bare endpoints own only the callbacks declared here.
    class BareController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit
      include ::DefaultNoStore
      include ::SignEntryClassification

      # D-59: none of the bare endpoints is a Sign Entry. The family declares the exclusion once,
      # with its reason, so a new bare endpoint inherits a stated classification instead of an
      # implicit one.
      sign_entry_classification! :excluded,
                                 reason: "bare health, revision, robots, sitemap and JWKS probe endpoints"

      AUTHENTICATION_MODE = :bare

      prepend_before_action :apply_default_no_store

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
