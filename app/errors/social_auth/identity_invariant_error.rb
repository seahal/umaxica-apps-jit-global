# typed: false
# frozen_string_literal: true

module SocialAuth
  # D-48 L4: a social identity row without its Client is a broken invariant, never an unknown subject.
  # Maps to HTTP 500; the raiser records a FATAL event first.
  class IdentityInvariantError < BaseError
    def initialize(i18n_key = "errors.social_auth.fatal", **context)
      super(i18n_key, :internal_server_error, **context)
    end
  end
end
