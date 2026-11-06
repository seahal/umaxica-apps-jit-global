# frozen_string_literal: true

# A principal-side receipt exists only if its IAM mutation committed in the same transaction.
class OrgIamOperationOutcome < OrgPrincipalRecord
  validates :operation_id, :operation_kind, :actor_public_id, :subject_public_id, :request_digest, :result,
            presence: true
  validates :operation_kind, inclusion: { in: %w(grant revoke) }
  validates :request_digest, length: { maximum: 64 }
  validates :request_digest, format: { with: /\A[0-9a-f]{64}\z/ }

  public

  def readonly? = persisted?
end
