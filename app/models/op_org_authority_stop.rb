# typed: false
# frozen_string_literal: true

# The ORG OP authority-stop record (two.md 5.8 v2). Written only by OpAuthorityStopCommitter.
class OpOrgAuthorityStop < OpBaseOrgRecord
  REALM = "org"

  belongs_to :cause, class_name: "OpOrgAuthorityStopCause", inverse_of: :stops
  belongs_to :scope, class_name: "OpOrgAuthorityStopScope", inverse_of: :stops
  has_many :root_targets, class_name: "OpOrgAuthorityStopRootTarget", foreign_key: :stop_id, inverse_of: :stop,
                          dependent: :restrict_with_exception
  has_many :grant_targets, class_name: "OpOrgAuthorityStopGrantTarget", foreign_key: :stop_id, inverse_of: :stop,
                           dependent: :restrict_with_exception
  has_one :epoch_cutoff, class_name: "OpOrgAuthorityStopEpochCutoff", foreign_key: :stop_id, inverse_of: :stop,
                         dependent: :restrict_with_exception
  has_many :participants, class_name: "OpOrgAuthorityStopParticipant", foreign_key: :stop_id, inverse_of: :stop,
                          dependent: :restrict_with_exception

  validates :public_id, :principal_public_id, :authority_evidence_ref, :idempotency_digest, :occurred_at,
            presence: true
  validates :realm, inclusion: { in: [REALM] }, length: { maximum: 3 }
  validates :public_id, length: { maximum: 21 }
  validates :authority_evidence_ref, length: { maximum: 128 }
  validates :principal_public_id, length: { maximum: 255 }

  public

  def cause_name = OpAuthorityStopReference::CAUSES.key(cause_id)
end
