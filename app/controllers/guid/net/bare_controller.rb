# typed: false
# frozen_string_literal: true

module Guid
  module Net
    class BareController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit

      AUTHENTICATION_MODE = :bare

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
