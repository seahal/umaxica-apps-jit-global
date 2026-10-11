# typed: false
# frozen_string_literal: true

class PasskeyCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :retention

  def perform
    IdentityPasskeyCeremonyTransactionPurger.call
  end
end
