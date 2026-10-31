# typed: false
# frozen_string_literal: true

class IdentitySecretCredentialCeremonyReplayStore
  MODELS = {
    "app" => ClientSecretCredentialCeremonyTransaction,
    "org" => OperatorSecretCredentialCeremonyTransaction,
  }.freeze

  def self.for(surface)
    new(MODELS.fetch(surface.to_s) { raise IdentitySecretCredentialCeremonyContract::Error, "surface is invalid" })
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
    raise IdentitySecretCredentialCeremonyContract::Error, "transaction is not found"
  end

  private

  attr_reader :model_class
end
