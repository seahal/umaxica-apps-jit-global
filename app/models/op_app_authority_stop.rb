# typed: false
# frozen_string_literal: true

# The APP OP authority-stop record (two.md 5.8 v2). Written only by OpAuthorityStopCommitter.
class OpAppAuthorityStop < OpBaseAppRecord
  REALM = "app"

  belongs_to :cause, class_name: "OpAppAuthorityStopCause", inverse_of: :stops
  belongs_to :scope, class_name: "OpAppAuthorityStopScope", inverse_of: :stops
  has_many :root_targets, class_name: "OpAppAuthorityStopRootTarget", foreign_key: :stop_id, inverse_of: :stop,
                          dependent: :restrict_with_exception
  has_many :grant_targets, class_name: "OpAppAuthorityStopGrantTarget", foreign_key: :stop_id, inverse_of: :stop,
                           dependent: :restrict_with_exception
  has_one :epoch_cutoff, class_name: "OpAppAuthorityStopEpochCutoff", foreign_key: :stop_id, inverse_of: :stop,
                         dependent: :restrict_with_exception
  has_many :participants, class_name: "OpAppAuthorityStopParticipant", foreign_key: :stop_id, inverse_of: :stop,
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
