# typed: false
# frozen_string_literal: true

class SocialCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :retention

  def perform
    IdentitySocialCeremonyTransactionPurger.call
  end
end
