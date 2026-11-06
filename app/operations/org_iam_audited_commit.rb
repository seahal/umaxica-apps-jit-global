# frozen_string_literal: true

# Coordinates the separate Chronicle and Zenith commits. A Chronicle intent alone never proves
# the principal mutation happened, and an indeterminate commit is never recorded as failed.
class OrgIamAuditedCommit
  Result = Data.define(:status, :outcome)

  class InvalidRequest < StandardError; end

  class OperationConflict < StandardError; end

  class OutcomeUnavailable < StandardError; end

  class << self
    public

    def call(**arguments, &)
      new(**arguments).call(&)
    end
  end

  def initialize(actor:, subject:, token:, evidence:, operation_id:, operation_kind:, request_digest:,
                 reason_code:, metadata:, request_id:, ip_address:, user_agent:, authorize:)
    @actor, @subject, @token, @evidence = actor, subject, token, evidence
    @operation_id, @operation_kind, @request_digest = operation_id, operation_kind, request_digest
    @reason_code, @metadata, @request_id, @ip_address, @user_agent =
      reason_code, metadata, request_id, ip_address, user_agent
    @authorize = authorize
  end

  public

  def call(&mutation)
    raise InvalidRequest unless mutation && authorize.is_a?(Proc) && actor.is_a?(Operator) &&
      subject.is_a?(Operator) && operation_id.is_a?(String) &&
      OrgAdministrativeAudit::OPERATION_ID_FORMAT.match?(operation_id) &&
      operation_kind.in?(%w(grant revoke)) && request_digest.is_a?(String) &&
      /\A[0-9a-f]{64}\z/.match?(request_digest)

    existing = Chronicle.find_by(event_uuid: operation_id)
    return reconcile(existing) if existing

    chronicle = create_intent
    return reconcile(Chronicle.find_by!(event_uuid: operation_id)) unless chronicle

    begin
      result = OrgIamPrincipalCommit.call(
        actor:, token:, evidence:, operation_id:, operation_kind:, subject_public_id: subject.public_id,
        request_digest:, authorize:, &mutation
      )
    rescue OrgIamPrincipalCommit::IndeterminateCommit
      return Result.new(status: :indeterminate, outcome: nil)
    rescue OrgIamPrincipalCommit::EvidenceRejected, OrgIamPrincipalCommit::AuthorizationRejected
      return finish_denial(chronicle)
    rescue OperatorCapabilityGrant::LastCapabilityHolderError => e
      return finish_domain_failure(chronicle, e)
    end
    finish_success(chronicle, result.record)
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionTimeoutError,
         ActiveRecord::StatementInvalid
    Result.new(status: :indeterminate, outcome: nil)
  end

  private

  attr_reader :actor, :subject, :token, :evidence, :operation_id, :operation_kind, :request_digest,
              :reason_code, :metadata, :request_id, :ip_address, :user_agent, :authorize

  def action
    (operation_kind == "grant") ? "iam.capability.granted" : "iam.capability.revoked"
  end

  def create_intent
    ChronicleIntentWriter.call(
      event_uuid: operation_id, action:, actor:, subject:, reason: reason_code,
      metadata: metadata.merge(iam_request_digest_parts: request_digest.scan(/.{16}/)), changeset: {},
      request_id:, ip_address:, user_agent:,
    )
  rescue ActiveRecord::RecordNotUnique
    nil
  rescue ActiveRecord::RecordInvalid => e
    raise unless e.record.errors.of_kind?(:event_uuid, :taken)

    nil
  end

  def reconcile(chronicle)
    validate_intent!(chronicle)
    return Result.new(status: :audit_unconfirmed, outcome: nil) unless chronicle.result.in?(%w(intent succeeded))

    record = OrgIamOperationOutcome.find_by(operation_id: operation_id)
    return Result.new(status: :indeterminate, outcome: nil) unless record

    validate_outcome!(record)
    verified =
      OrgIamPrincipalCommit.call(
        actor:, token:, evidence:, operation_id:, operation_kind:, subject_public_id: subject.public_id,
        request_digest:, authorize:,
      ) { raise OutcomeUnavailable, "recorded outcome disappeared" }
    return Result.new(status: :confirmed, outcome: verified.record) if chronicle.result == "succeeded"

    finish_success(chronicle, verified.record)
  rescue OrgIamPrincipalCommit::EvidenceRejected, OrgIamPrincipalCommit::AuthorizationRejected
    Result.new(status: :denied, outcome: nil)
  rescue OrgIamPrincipalCommit::IndeterminateCommit, OutcomeUnavailable
    Result.new(status: :indeterminate, outcome: nil)
  end

  def validate_intent!(chronicle)
    return if chronicle.action == action && chronicle.reason == reason_code &&
      chronicle.actor_type == actor.class.name && chronicle.actor_id == actor.id &&
      chronicle.subject_type == subject.class.name && chronicle.subject_id == subject.id &&
      chronicle.metadata["iam_request_digest_parts"] == request_digest.scan(/.{16}/)

    raise OperationConflict, "IAM operation id already has different input"
  end

  def validate_outcome!(record)
    return if record.operation_kind == operation_kind && record.actor_public_id == actor.public_id &&
      record.subject_public_id == subject.public_id && record.request_digest == request_digest

    raise OperationConflict, "IAM operation id already has different input"
  end

  def finish_success(chronicle, record)
    changeset = (operation_kind == "revoke") ? { "revoked" => true } : record.result
    ChronicleResultWriter.call(
      chronicle:, result: "succeeded", event_uuid: operation_id, request_id:, action:, actor:, subject:,
      changeset:,
    )
    Result.new(status: :confirmed, outcome: record)
  rescue StandardError
    Result.new(status: :audit_unconfirmed, outcome: nil)
  end

  def finish_denial(chronicle)
    ChronicleResultWriter.call(
      chronicle:, result: "failed", event_uuid: operation_id, request_id:, action:, actor:, subject:,
      changeset: { denied: true },
    )
    Result.new(status: :denied, outcome: nil)
  rescue StandardError
    Result.new(status: :audit_unconfirmed, outcome: nil)
  end

  def finish_domain_failure(chronicle, error)
    ChronicleResultWriter.call(
      chronicle:, result: "failed", event_uuid: operation_id, request_id:, action:, actor:, subject:,
      changeset: { error_class: error.class.name },
    )
    Result.new(status: :last_capability_holder, outcome: nil)
  rescue StandardError
    Result.new(status: :audit_unconfirmed, outcome: nil)
  end
end
