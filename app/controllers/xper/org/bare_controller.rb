# typed: false
# frozen_string_literal: true

module Xper
  module Org
    # Operational endpoints bypass the application lifecycle and declare edge protection here.
    class BareController < ActionController::Base
      include ::FqdnAvailabilityGate
      include ::RateLimit

      AUTHENTICATION_MODE = :bare

      protect_from_forgery using: :header_or_legacy_token, with: :exception
    end
  end
end
