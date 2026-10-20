# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_entra_identities
# Database name: org_zenith
#
#  id                    :bigint           not null, primary key
#  public_id             :string(21)       not null
#  operator_id           :bigint           not null
#  connection_id         :bigint
#  entra_tenant_id       :string(36)       not null
#  entra_object_id       :string(36)       not null
#  evidence_issuer       :string(512)
#  evidence_subject      :string(512)
#  status_id             :bigint           not null, default: 0
#  last_authenticated_at :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_operator_entra_identities_on_public_id      (public_id) UNIQUE
#  idx_operator_entra_identities_on_tid_and_oid      (entra_tenant_id, entra_object_id) UNIQUE
#  index_operator_entra_identities_on_operator_id    (operator_id) UNIQUE
#  index_operator_entra_identities_on_connection_id  (connection_id)
#  index_operator_entra_identities_on_status_id      (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => operator_entra_identity_states.id)
#
# Lookup key is (entra_tenant_id, entra_object_id) -- the Entra (tid, oid) pair.
# evidence_issuer and evidence_subject store iss/sub for audit only; never used for auth lookup.
# operator_id is unique (v1: one Entra identity per Operator; intentionally strict).
# operator_id is a logical reference to operators in org_principal (cross-DB; no enforced FK).
# See adr/org-entra-id-sign-in-boundary.md.
class OperatorEntraIdentity < OrgRpRecord
  include ::PublicId

  ENTRA_ID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  private_constant :ENTRA_ID_FORMAT

  belongs_to :identity_state,
             class_name: "OperatorEntraIdentityState",
             foreign_key: :status_id,
             inverse_of: :operator_entra_identities

  # Optional: the org surface federates a single Entra tenant configured in
  # Rails credentials, so sign-in resolves an identity by (tid, oid) alone and
  # never reads a connection. The association remains for records provisioned
  # before that change.
  belongs_to :connection,
             class_name: "OrganizationEntraConnection",
             inverse_of: :operator_entra_identities,
             optional: true

  validates :operator_id, :entra_tenant_id, :entra_object_id,
            presence: true
  validates :operator_id, uniqueness: true
  validates :entra_tenant_id, uniqueness: { scope: :entra_object_id }
  validates :entra_tenant_id, format: { with: ENTRA_ID_FORMAT, message: :uuid_format }
  validates :entra_object_id, format: { with: ENTRA_ID_FORMAT, message: :uuid_format }
  validates :entra_object_id, :entra_tenant_id, length: { maximum: 36 }
  validates :evidence_issuer, :evidence_subject, length: { maximum: 512 }
end
