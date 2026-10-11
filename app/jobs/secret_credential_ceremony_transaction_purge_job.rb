# typed: false
# frozen_string_literal: true

class SecretCredentialCeremonyTransactionPurgeJob < ApplicationJob
  queue_as :retention

  def perform
    IdentitySecretCredentialCeremonyTransactionPurger.new.call
  end
end
