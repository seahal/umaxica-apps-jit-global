# typed: false
# frozen_string_literal: true

# The one named writer of OP client admission (R5-WU19, one.md section 8 "Activation authority").
# Enables or disables an exact RP client for the realm OP's current contract epoch, recording who
# did it, the audit reference and the digest of the source manifest the decision was made against.
# Opening OP admission is a separate recorded control action from enabling the RP cell's browser
# entry; this class never touches an RP store.
class OpClientActivationWriter
  Result = Data.define(:client_id, :contract_epoch, :enabled)

  def initialize(client_id:, enabled:, actor_ref:, audit_ref:, source_manifest_digest:)
    @cell = RpCellBinding.for_client(client_id)
    raise ArgumentError, "enabled must be true or false" unless [true, false].include?(enabled)

    @enabled = enabled

    @actor_ref = require_value(actor_ref, "actor_ref")
    @audit_ref = require_value(audit_ref, "audit_ref")
    @source_manifest_digest = require_value(source_manifest_digest, "source_manifest_digest")
  end

  class << self
    public

    def call(...) = new(...).call
  end

  public

  def call
    activation_class, epoch_class = OpClientAdmissionQuery::REALMS.fetch(cell.realm)
    activation_class.transaction do
      # The epoch row lock serializes admission changes against an epoch change of the same realm.
      epoch = epoch_class.lock.find(1).contract_epoch
      row = activation_class.lock.find_or_initialize_by(client_id: cell.client_id, contract_epoch: epoch)
      row.update!(
        enabled:, changed_at: Time.current, actor_ref:, audit_ref:, source_manifest_digest:,
      )
      Result.new(client_id: cell.client_id, contract_epoch: epoch, enabled:)
    end
  end

  private

  attr_reader :cell, :enabled, :actor_ref, :audit_ref, :source_manifest_digest

  def require_value(value, name)
    raise ArgumentError, "#{name} is required" unless value.is_a?(String) && value.present?

    value
  end
end
