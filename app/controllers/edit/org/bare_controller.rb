# typed: false
# frozen_string_literal: true

module Edit
  module Org
    class BareController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit

      AUTHENTICATION_MODE = :bare

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
