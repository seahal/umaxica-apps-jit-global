# typed: false
# frozen_string_literal: true

class TotpCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :retention

  def perform
    IdentityTotpCeremonyTransactionPurger.new.call
  end
end
