# typed: false
# frozen_string_literal: true

# Persisted admission of one exact RP client at one contract epoch (R5-WU19). Written only by
# OpClientActivationWriter; read by OpClientAdmissionQuery at the OP authorization/token endpoints.
class OpOrgClientActivation < OpBaseOrgRecord
  self.table_name = "op_client_activations"

  validates :client_id, uniqueness: { scope: :contract_epoch }, on: :create
  validates :client_id, presence: true, length: { maximum: 64 }
  validates :contract_epoch, numericality: { only_integer: true, greater_than: 0 }
  validates :changed_at, :actor_ref, :audit_ref, presence: true
  validates :source_manifest_digest, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :source_manifest_digest, length: { maximum: 64 }
  validates :actor_ref, :audit_ref, length: { maximum: 255 }
  validates :source_manifest_digest, exclusion: { in: [nil] }
end
