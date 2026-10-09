# typed: false
# frozen_string_literal: true

module Sign
  # Base exception for withdrawal-related errors
  class WithdrawalError < ApplicationError
    def initialize(i18n_key, status_code = :bad_request, **context)
      super
    end
  end
end
