# typed: false
# frozen_string_literal: true

class IdentityEmailCeremonyTransactionPurger
  MODELS = {
    app: ClientEmailCeremonyTransaction,
    org: OperatorEmailCeremonyTransaction,
  }.freeze

  def initialize(now: Time.current, retention_period: EmailCeremonyTransactionable::RETENTION_PERIOD,
                 batch_size: 1000)
    @now = now
    @retention_period = retention_period
    @batch_size = batch_size
  end

  def call
    MODELS.transform_values { |model| purge_model(model) }
  end

  private

  attr_reader :now, :retention_period, :batch_size

  def purge_model(model)
    count = 0
    loop do
      ids = model.purgeable_at(now, retention_period: retention_period).limit(batch_size).pluck(:id)
      break if ids.empty?

      count += model.where(id: ids).delete_all
    end
    count
  end
end
