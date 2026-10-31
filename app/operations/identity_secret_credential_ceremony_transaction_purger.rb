# typed: false
# frozen_string_literal: true

class IdentitySecretCredentialCeremonyTransactionPurger
  MODELS = {
    app: ClientSecretCredentialCeremonyTransaction,
    org: OperatorSecretCredentialCeremonyTransaction,
  }.freeze

  def initialize(now: Time.current, retention_period: SecretCredentialCeremonyTransactionable::RETENTION_PERIOD)
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
