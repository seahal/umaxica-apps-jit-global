# typed: false
# frozen_string_literal: true

class IdentityStepUpCeremonyTransactionPurger
  MODEL_BY_SURFACE = {
    app: ClientStepUpCeremonyTransaction,
    com: VisitorStepUpCeremonyTransaction,
    org: OperatorStepUpCeremonyTransaction,
  }.freeze
  DEPENDENT_MODELS = {
    ClientStepUpCeremonyTransaction => [
      ClientAuthCeremonySession, ClientStepUpSession, ClientPasskeyCeremonyTransaction,
      ClientTotpCeremonyTransaction, IdentityTotpCeremonyCandidate, IdentityPasskeyCeremonyCandidate,
    ],
    VisitorStepUpCeremonyTransaction => [
      VisitorAuthCeremonySession, VisitorStepUpSession, VisitorPasskeyCeremonyTransaction,
      VisitorPasskeyCeremonyCandidate,
    ],
    OperatorStepUpCeremonyTransaction => [
      OperatorAuthCeremonySession, OperatorStepUpSession, OperatorPasskeyCeremonyTransaction,
      OperatorPasskeyCeremonyCandidate,
    ],
  }.freeze

  def initialize(now: Time.current, retention_period: StepUpCeremonyTransactionable::RETENTION_PERIOD,
                 batch_size: 500)
    @now = now
    @retention_period = retention_period
    @batch_size = batch_size
  end

  public

  def call
    MODEL_BY_SURFACE.transform_values { |model| purge_model(model) }
  end

  private

  attr_reader :now, :retention_period, :batch_size

  def purge_model(model)
    deleted = 0
    model.connection_owner.connected_to(role: :writing) do
      model.purgeable_at(now, retention_period: retention_period).in_batches(of: batch_size) do |batch|
        batch.each do |parent|
          parent.with_lock do
            cutoff = now - retention_period
            terminal_times = parent.attributes.values_at("consumed_at", "canceled_at", "revoked_at")
            next unless parent.expires_at <= cutoff && terminal_times.all? { |time| time.nil? || time <= cutoff }
            next unless AuthAdmissionBindingPurger.purge_for_parent!(
              parent:, now:, retention_period:,
            )

            children =
              DEPENDENT_MODELS.fetch(model).map do |child_model|
                child_model.where(step_up_ceremony_transaction_ref: parent.transaction_id)
              end
            eligible = children.map { |relation| eligible_children(relation) }
            next unless children.zip(eligible).all? { |all, old| all.count == old.count }

            # Restrictive FKs remain intact. A concurrent new reference aborts the whole writer
            # transaction rather than leaving partially removed continuity or reviving authority.
            eligible.each(&:delete_all)
            deleted += model.where(id: parent.id).delete_all
          end
        end
      end
    end
    deleted
  end

  def eligible_children(relation)
    model = relation.klass
    cutoff = now - retention_period
    if [ClientStepUpSession, VisitorStepUpSession, OperatorStepUpSession].include?(model)
      relation.where(model.arel_table[:discard_at].lteq(cutoff))
        .where(model.arel_table[:purge_eligible_at].lteq(now))
    elsif [ClientAuthCeremonySession, VisitorAuthCeremonySession, OperatorAuthCeremonySession].include?(model)
      expired = relation.where(model.arel_table[:expires_at].lteq(cutoff))
      %i(completed_at cancelled_at revoked_at).reduce(expired) do |scope, column|
        scope.where(model.arel_table[column].eq(nil).or(model.arel_table[column].lteq(cutoff)))
      end
    elsif [ClientPasskeyCeremonyTransaction, VisitorPasskeyCeremonyTransaction, OperatorPasskeyCeremonyTransaction,
           ClientTotpCeremonyTransaction, IdentityTotpCeremonyCandidate,
           IdentityPasskeyCeremonyCandidate, VisitorPasskeyCeremonyCandidate,
           OperatorPasskeyCeremonyCandidate,].include?(model)
      relation.where(model.arel_table[:expires_at].lteq(cutoff))
        .where(model.arel_table[:consumed_at].eq(nil).or(model.arel_table[:consumed_at].lteq(cutoff)))
    else
      raise ArgumentError, "unsupported ceremony dependent"
    end
  end
end
