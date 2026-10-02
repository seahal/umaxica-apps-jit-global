# typed: false
# frozen_string_literal: true

class OidcAuthorizationTransactionPurgeJob < ApplicationJob
  queue_as :retention

  public

  def perform
    OidcAuthorizationTransactionPurger.call
  end
end
