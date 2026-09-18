# typed: false
# frozen_string_literal: true

class EmailCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :retention

  def perform(batch_size: 1000)
    IdentityEmailCeremonyTransactionPurger.new(batch_size: batch_size).call
  end
end
