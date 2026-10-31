# typed: false
# frozen_string_literal: true

class IdentityTelephoneCeremonyTransactionPurger
  MODEL_BY_SURFACE = {
    app: ClientTelephoneCeremonyTransaction,
    org: OperatorTelephoneCeremonyTransaction,
  }.freeze

  def initialize(now: Time.current, retention_period: TelephoneCeremonyTransactionable::RETENTION_PERIOD,
                 batch_size: 500)
    @now = now
    @retention_period = retention_period
    @batch_size = batch_size
  end

  def call
    MODEL_BY_SURFACE.transform_values { |model| purge_model(model) }
  end

  private

  attr_reader :now, :retention_period, :batch_size

  def purge_model(model)
    deleted = 0
    model.connection_owner.connected_to(role: :writing) do
      model.purgeable_at(now, retention_period: retention_period).in_batches(of: batch_size) do |batch|
        # Ceremony transaction rows have no callbacks or dependent records;
        # delete_all keeps this retention pass cheap and connection-local.
        deleted += batch.delete_all
      end
    end
    deleted
  end
end
