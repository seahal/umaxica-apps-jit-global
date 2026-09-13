# typed: false
# frozen_string_literal: true

class AlreadyAuthenticatedError < ApplicationError
  MESSAGE = "Sign-in is unavailable while authenticated."

  def initialize(_i18n_key = nil, status_code = :conflict, **context)
    super(nil, status_code, **context)
  end

  def message
    MESSAGE
  end
end
