# frozen_string_literal: true

# Principal-side IAM commit primitive. The caller owns Chronicle intent/result and must only
# report completion after the result is durable. This primitive is not an authorization policy:
# its block must recheck the specific grant or revoke policy under the locked actor and rows.
class OrgIamPrincipalCommit
  class NestedTransactionError < StandardError; end

  class EvidenceRejected < StandardError; end

  class AuthorizationRejected < StandardError; end

  class OperationConflict < StandardError; end

  class IndeterminateCommit < StandardError; end

  Result = Data.define(:outcome, :record)

  class << self
    public

    def call(actor:, token:, evidence:, operation_id:, operation_kind:, subject_public_id:, request_digest:,
             authorize:, &)
      new(actor:, token:, evidence:, operation_id:, operation_kind:, subject_public_id:, request_digest:, authorize:)
        .call(&)
    end
  end

  def initialize(actor:, token:, evidence:, operation_id:, operation_kind:, subject_public_id:, request_digest:,
                 authorize:)
    @actor = actor
    @token = token
    @evidence = evidence
    @operation_id = operation_id
    @operation_kind = operation_kind
    @subject_public_id = subject_public_id
    @request_digest = request_digest
    @authorize = authorize
  end

  public

  def call
    raise ArgumentError, "IAM commit requires a mutation block" unless block_given?

    validate_actor_and_token!

    committed = nil
    ensure_outermost_transactions!
    principal_connection = OrgZenithRecord.lease_connection
    op_connection = OpBaseOrgRecord.lease_connection
    OpBaseOrgRecord.transaction do
      OrgZenithRecord.transaction do
        committed = commit_outcome { |locked_actor| yield locked_actor }
      end
      # This assignment occurs only after the Zenith transaction acknowledged COMMIT.
      @principal_commit_confirmed = true
    end
    Result.new(outcome: :confirmed, record: committed)
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionTimeoutError,
         ActiveRecord::StatementInvalid, ActiveRecord::SQLWarning => e
    # A connection involved in an uncertain commit or release must never return to the pool.
    op_connection&.throw_away!
    if @principal_commit_confirmed
      Rails.logger.warn(JitLogEvent.format("iam.op_transaction_release_failed", reason_code: "op_release_failed"))
      return Result.new(outcome: :confirmed_op_release_failed, record: committed)
    end

    principal_connection&.throw_away!
    raise IndeterminateCommit, e.class.name unless @authorization_confirmed

    record =
      OrgZenithRecord.connected_to(role: :writing) do
        OrgIamOperationOutcome.find_by(operation_id: operation_id)
      end
    raise IndeterminateCommit, e.class.name unless record

    Result.new(outcome: :confirmed_after_recovery, record: matching_outcome!(record))
  end

  private

  attr_reader :actor, :token, :evidence, :operation_id, :operation_kind, :subject_public_id, :request_digest, :authorize

  def commit_outcome
    locked_actor = lock_principals!
    OperatorCapabilityGrant.where(operator_id: locked_actor.id).order(:id).lock.load
    raise EvidenceRejected unless StepUpEvidenceVerifier.call(evidence:, actor: locked_actor, token:)
    raise AuthorizationRejected unless authorize.call(locked_actor)

    @authorization_confirmed = true
    existing = OrgIamOperationOutcome.find_by(operation_id: operation_id)
    if existing
      committed = matching_outcome!(existing)
    else
      result = yield locked_actor
      raise EvidenceRejected unless StepUpEvidenceVerifier.call(evidence:, actor: locked_actor, token:)
      raise AuthorizationRejected unless authorize.call(locked_actor)

      committed = OrgIamOperationOutcome.create!(
        operation_id:, operation_kind:, actor_public_id: locked_actor.public_id,
        subject_public_id:, request_digest:, result: result,
      )
    end
    committed
  end

  def lock_principals!
    subject_id = Operator.where(public_id: subject_public_id).pick(:id)
    raise ActiveRecord::RecordNotFound, "IAM subject is unavailable" unless subject_id

    principals = Operator.where(id: [actor.id, subject_id]).order(:id).lock.to_a
    raise ActiveRecord::RecordNotFound, "IAM principal is unavailable" unless principals.size == [actor.id,
                                                                                                  subject_id,].uniq.size

    principals.find { |principal| principal.id == actor.id }
  end

  def validate_actor_and_token!
    return if actor.is_a?(Operator) && token.is_a?(OperatorToken) && token.staff_id == actor.id

    raise ArgumentError, "IAM commit requires an Operator and its token"
  end

  def ensure_outermost_transactions!
    return if OrgZenithRecord.lease_connection.open_transactions.zero? &&
      OpBaseOrgRecord.lease_connection.open_transactions.zero?

    raise NestedTransactionError, "IAM commit requires ownership of both transactions"
  end

  def matching_outcome!(record)
    return record if record.operation_kind == operation_kind && record.actor_public_id == actor.public_id &&
      record.subject_public_id == subject_public_id && record.request_digest == request_digest

    raise OperationConflict, "IAM operation id already has different input"
  end
end
