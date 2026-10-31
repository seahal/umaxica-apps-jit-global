# typed: false
# frozen_string_literal: true

class IdentityPasskeyCeremonyTransactionPurger
  MODELS = {
    "app" => ClientPasskeyCeremonyTransaction,
    "org" => OperatorPasskeyCeremonyTransaction,
  }.freeze

  def self.call(now: Time.current, retention_period: PasskeyCeremonyTransactionable::RETENTION_PERIOD)
    new(now: now, retention_period: retention_period).call
  end

  def initialize(now: Time.current, retention_period: PasskeyCeremonyTransactionable::RETENTION_PERIOD)
    @now = now
    @retention_period = retention_period
  end

  def call
    MODELS.transform_values do |model|
      model.connection_owner.connected_to(role: :writing) do
        model.purgeable_at(now, retention_period: retention_period).delete_all
      end
    end
  end

  private

  attr_reader :now, :retention_period
end
