# typed: false
# frozen_string_literal: true

class AlreadyAuthenticatedError < ApplicationError
  def initialize(_i18n_key = nil, status_code = :forbidden, **context)
    super(nil, status_code, **context)
  end

  def message
    I18n.t("errors.messages.operation_not_permitted")
  end
end
