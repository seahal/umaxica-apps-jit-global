# typed: false
# frozen_string_literal: true

class OrgOperatorLifecycleExecute
  GRACE_PERIOD = 31.days

  def self.call(request:, actor:)
    new(request: request, actor: actor).call
  end

  def initialize(request:, actor:)
    @request = request
    @actor = actor
  end

  def call
    return failure("Only approved requests can be executed") unless request.approved?
    return failure("Requester cannot execute their own lifecycle request") if requested_by_actor?

    invitation = nil
    OrgPrincipalRecord.transaction do
      invitation = execute_action!
      request.update!(
        status: OperatorLifecycleRequest::STATUS_EXECUTED,
        executed_by_operator: actor,
        executed_at: Time.current,
        invitation_id: invitation&.id,
      )
    end

    OrgOperatorLifecycleResult.new(success: true, request: request, error: nil, invitation: invitation)
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages.to_sentence)
  end

  private

  attr_reader :request, :actor

  def execute_action!
    case request.action
    when OperatorLifecycleRequest::ACTION_JOIN
      create_invitation!
    when OperatorLifecycleRequest::ACTION_WITHDRAW
      withdraw_operator!
      nil
    when OperatorLifecycleRequest::ACTION_SUSPEND
      suspend_operator!
      nil
    when OperatorLifecycleRequest::ACTION_TERMINATE
      terminate_operator!
      nil
    when OperatorLifecycleRequest::ACTION_RESTORE
      restore_operator!
      nil
    else
      raise ActiveRecord::RecordInvalid, request
    end
  end

  def create_invitation!
    result = OrgOperatorLifecycleInvitationIssuer.call(request: request, actor: actor)
    raise ActiveRecord::RecordInvalid, request unless result.success?

    result.invitation
  end

  # Leaving, with a window to change their mind: the operator is deactivated now
  # and purged after GRACE_PERIOD unless `restore` runs first.
  def withdraw_operator!
    target = request.target_operator
    return if target.blank?

    ensure_not_last_active_operator!(target)
    revoke_target_sessions!(target)
    withdraw_entra_identity!(target, OperatorEntraIdentityState::SUSPENDED)
    now = Time.current
    target.update!(
      withdrawal_started_at: target.withdrawal_started_at || now,
      deactivated_at: target.deactivated_at || now,
      discard_at: now,
      purge_eligible_at: now + GRACE_PERIOD,
    )
  end

  # Not leaving: a leave of absence or a disciplinary suspension. The person is
  # expected back, so this sets no deletion countdown at all -- only
  # `deactivated_at`, which is what `Withdrawable#suspended?` reads and what the
  # authentication gates refuse. `withdrawal_started_at`, `discard_at`, and
  # `purge_eligible_at` stay untouched, so the record survives a leave of any length and
  # `restore` brings it back.
  #
  # This used to share the withdrawal branch, which meant filing a suspension
  # silently scheduled the operator for deletion in GRACE_PERIOD days. The reason
  # for the suspension belongs in the request's `reason`, not in a separate state.
  def suspend_operator!
    target = request.target_operator
    return if target.blank?

    ensure_not_last_active_operator!(target)
    revoke_target_sessions!(target)
    withdraw_entra_identity!(target, OperatorEntraIdentityState::SUSPENDED)
    target.update!(deactivated_at: target.deactivated_at || Time.current)
  end

  def terminate_operator!
    target = request.target_operator
    return if target.blank?

    ensure_not_last_active_operator!(target)
    revoke_target_sessions!(target)
    withdraw_entra_identity!(target, OperatorEntraIdentityState::REVOKED)
    now = Time.current
    target.update!(
      withdrawal_started_at: target.withdrawal_started_at || now,
      deactivated_at: target.deactivated_at || now,
      withdrawn_at: target.withdrawn_at || now,
      discard_at: now,
      purge_eligible_at: now,
    )
  end

  # Deliberately does not reactivate the operator's Entra identity. Restoring an
  # operator returns their own credentials; re-granting a federated sign-in is a
  # separate decision, made explicitly through `rake entra_identity:activate`.
  # Silently reviving it would undo the deny-by-default the identity table exists
  # to express (adr/org-entra-id-sign-in-boundary.md).
  def restore_operator!
    target = request.target_operator
    return if target.blank?

    target.update!(
      withdrawal_started_at: nil,
      deactivated_at: nil,
      withdrawn_at: nil,
      discard_at: Float::INFINITY,
      purge_eligible_at: Float::INFINITY,
    )
  end

  def revoke_target_sessions!(target)
    target.staff_tokens.not_revoked.find_each(&:revoke!)
  end

  # Logical delete: the row keeps (tid, oid), the protocol evidence, and
  # last_authenticated_at so the mapping stays auditable after the person leaves.
  # It is deleted for real when the operator is purged
  # (RetentionCrossDatabaseChildPurge).
  #
  # This writes to org_zenith while the surrounding transaction is on
  # org_principal, so the two are not atomic. The order is chosen so the
  # surviving inconsistency is the safe one: if the operator update then fails,
  # the identity is already withdrawn and the person cannot sign in with Entra,
  # rather than the reverse.
  def withdraw_entra_identity!(target, status_id)
    identity = OperatorEntraIdentity.find_by(operator_id: target.id)
    return if identity.nil?

    identity.update!(status_id: status_id)
  end

  def ensure_not_last_active_operator!(target)
    active_count =
      Operator
        .where(deactivated_at: nil, withdrawn_at: nil)
        .where(Operator.arel_table[:discard_at].gt(Time.current))
        .where.not(id: target.id)
        .count
    return if active_count.positive?

    request.errors.add(:base, "Cannot deactivate the last active operator")
    raise ActiveRecord::RecordInvalid, request
  end

  def requested_by_actor?
    request.requested_by_operator_id == actor.id
  end

  def failure(error)
    OrgOperatorLifecycleResult.new(success: false, request: request, error: error, invitation: nil)
  end
end
