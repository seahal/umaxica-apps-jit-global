# typed: false
# frozen_string_literal: true

class IdentityStepUpCeremonyReplayStore
  MODEL_BY_SURFACE = {
    "app" => ClientStepUpCeremonyTransaction,
    "org" => OperatorStepUpCeremonyTransaction,
  }.freeze

  def self.for(surface)
    new(
      transaction_class: MODEL_BY_SURFACE.fetch(surface.to_s) {
        raise IdentityStepUpCeremonyContract::Error, "surface is invalid"
      },
    )
  end

  def initialize(transaction_class:)
    @transaction_class = transaction_class
  end

  def create_transaction!(**attributes)
    transaction_class.create_transaction!(**attributes)
  end

  def find_transaction!(transaction_id)
    transaction_class.find_by!(transaction_id: transaction_id)
  end

  def latest_pending_for(**attributes)
    transaction_class.latest_pending_for(**attributes)
  end

  def consumed?(result_jti)
    transaction_class.exists?(result_jti: result_jti)
  end

  private

  attr_reader :transaction_class
end
