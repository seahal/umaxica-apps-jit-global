# typed: false
# frozen_string_literal: true

class IdentityEmailCeremonyReplayStore
  MODELS = {
    "app" => ClientEmailCeremonyTransaction,
    "org" => OperatorEmailCeremonyTransaction,
  }.freeze

  def self.for(surface)
    new(MODELS.fetch(surface.to_s) { raise IdentityEmailCeremonyContract::Error, "surface is invalid" })
  end

  def initialize(model_class)
    @model_class = model_class
  end

  def create_transaction!(**attributes)
    model_class.create_transaction!(**attributes)
  end

  def find_transaction!(transaction_id)
    model_class.find_by!(transaction_id: transaction_id)
  rescue ActiveRecord::RecordNotFound
    raise IdentityEmailCeremonyContract::Error, "transaction is not found"
  end

  private

  attr_reader :model_class
end
