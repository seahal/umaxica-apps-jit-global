# typed: false
# frozen_string_literal: true

class AuthenticationLogoutCurrentSession
  class CommitOutcomeUnknown < StandardError; end

  class PreconditionFailed < StandardError; end

  def self.call(...)
    new(...).call
  end

  # cause - the two.md 5.8 v2 authority-stop cause (D-172, D-173); every root this sign-out ends is
  #         stopped through OpAuthorityStopCommitter with it (BX-1).
  # browser_binding - for browser_logout / rp_initiated_logout, binds the one-time receipt of the
  #         stop of the presented root to this browser.
  def initialize(cause:, current: nil, resource: nil, token: nil, token_class: nil, session_public_id: nil,
                 reason: "user_logout", cascade_device_session_tokens: true, precondition: nil,
                 browser_binding: nil)
    @cause = cause.to_s
    OpAuthorityStopReference.cause_id(@cause)
    @current = current
    @resource = resource
    @token = token
    @token_class = token_class
    @session_public_id = session_public_id.presence || current_session_from_current
    @reason = reason
    @cascade_device_session_tokens = cascade_device_session_tokens
    @precondition = precondition
    @browser_binding = browser_binding
    @stop_results = []
  end

  # The authority-stop results committed by #call, the presented root's first.
  attr_reader :stop_results

  def call
    token_record = resolved_token
    return stop_risk_authority!(token_record) if cause == "risk" && !op_root?(token_record)

    with_token_writing_connection(token_record) do
      verify_precondition_under_parent_lock!(token_record)
      stop_authority!(token_record)
    end
    true
  end

  private

  # A risk event without a resolved OP root is principal-wide and begins in the actor store before
  # the stop is applied in OP, preserving the Zenith -> OP lock order.
  def stop_risk_authority!(_token_record)
    actor = resource
    unless [Client, Visitor, Operator].include?(actor.class) && actor.persisted?
      raise OpAuthorityStopCommitter::Refused, "risk stop requires an established principal"
    end

    SignRiskEnforcer.revoke!(actor)
    true
  end

  attr_reader :cause, :current, :resource, :token, :token_class, :session_public_id, :reason,
              :cascade_device_session_tokens, :precondition, :browser_binding

  # REQ-002: a caller's authority decision is re-checked inside the revoking transaction after the
  # parent Device Session row is locked, the first lock of the Device -> root -> RP order. A
  # concurrent rotation or revocation therefore cannot slip between the check and the COMMIT.
  def verify_precondition_under_parent_lock!(token_record)
    return if precondition.nil?

    device_session_for_token(token_record)&.lock!
    raise PreconditionFailed, "sign-out precondition no longer holds" unless precondition.call
  end

  def current_session_from_current
    return unless current.respond_to?(:session)

    current.session
  end

  def resolved_token
    return token if token.present?
    return if token_class.blank? || session_public_id.blank?

    device_session = token_column?(:device_session_id) ? find_device_session : nil
    if device_session
      return token_class.currently_usable_at
          .where(device_session_id: device_session.id)
          .order(created_at: :desc)
          .first
    end

    # A database failure here is not "no session": it propagates so the
    # sign-out is reported as incomplete instead of as an idempotent success.
    find_token_by(:public_id) || find_token_by(:oidc_sid)
  end

  def find_token_by(column)
    return unless token_column?(column)
    return if column == :oidc_sid && !uuid_identifier?(session_public_id)

    token_class.find_by(column => session_public_id)
  end

  def token_column?(column)
    return false unless token_class.respond_to?(:column_names)

    token_class.column_names.include?(column.to_s)
  end

  def uuid_identifier?(value)
    /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.match?(
      value.to_s,
    )
  end

  def find_device_session
    klass = device_session_class
    return unless klass

    klass.active.find_by(public_id: session_public_id)
  end

  def with_token_writing_connection(token_record, &)
    owner = connection_owner_for(token_record&.class || token_class)
    return yield if owner.blank?

    transaction_body_completed = false
    owner.connected_to(role: :writing) do
      owner.transaction(requires_new: true) do
        yield
        transaction_body_completed = true
      end
    end
  rescue StandardError => e
    raise unless transaction_body_completed && commit_outcome_error?(e)

    resolve_commit_outcome!(token_record, e)
  end

  def commit_outcome_error?(error)
    [error, error.cause].compact.any? do |candidate|
      candidate.is_a?(ActiveRecord::ConnectionFailed) ||
        candidate.is_a?(ActiveRecord::ConnectionNotEstablished) ||
        candidate.is_a?(PG::ConnectionBad)
    end
  end

  def resolve_commit_outcome!(token_record, commit_error)
    if parent_revocation_persisted?(token_record)
      Rails.logger.info(
        JitLogEvent.format(
          "auth.logout_current_session.commit_confirmed_after_connection_error",
          reason: reason,
          token_class: token_record&.class&.name,
          error_class: commit_error.class.name,
        ),
      )
      return true
    end

    Rails.logger.error(
      JitLogEvent.format(
        "auth.logout_current_session.commit_outcome_unknown",
        reason: reason,
        token_class: token_record&.class&.name,
        error_class: commit_error.class.name,
      ),
    )
    raise CommitOutcomeUnknown, "sign-out commit outcome is indeterminate"
  rescue CommitOutcomeUnknown
    raise
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "auth.logout_current_session.commit_outcome_unreadable",
        reason: reason,
        token_class: token_record&.class&.name,
        error_class: e.class.name,
      ),
    )
    raise CommitOutcomeUnknown, "sign-out commit outcome is indeterminate", cause: e
  end

  def parent_revocation_persisted?(token_record)
    return false unless token_record&.respond_to?(:id) && token_record.id.present?

    owner = connection_owner_for(token_record.class)
    return false if owner.blank?

    owner.connected_to(role: :writing) do
      owner.connection_pool.with_connection do
        persisted_token = token_record.class.unscoped.find_by(id: token_record.id)
        next false unless persisted_token&.respond_to?(:revoked?) && persisted_token.revoked?

        device_session =
          case persisted_token
          when ClientToken then ClientDeviceSession.find_by(id: persisted_token.device_session_id)
          when VisitorToken then VisitorDeviceSession.find_by(id: persisted_token.device_session_id)
          when OperatorToken then OperatorDeviceSession.find_by(id: persisted_token.device_session_id)
          end
        device_session&.revoked? == true
      end
    end
  end

  def connection_owner_for(klass)
    return unless klass.respond_to?(:connection_class?)

    owner = klass
    owner = owner.superclass until owner.connection_class? || owner == ApplicationRecord
    owner
  end

  def device_session_class
    case token_class&.name
    when "ClientToken" then ClientDeviceSession
    when "OperatorToken" then OperatorDeviceSession
    when "VisitorToken" then VisitorDeviceSession
    end
  end

  # Device Session -> each root through the one authority-stop primitive (which revokes the root
  # and every grant under it) -> the Device Session itself.
  def stop_authority!(token_record)
    device_session = device_session_for_token(token_record) || find_device_session
    stop_roots_for(token_record, device_session).each_with_index do |root, index|
      @stop_results << OpAuthorityStopCommitter.stop_root(
        root:, cause:, principal_public_id: principal_public_id_for(root),
        authority_evidence_ref: reason.to_s, browser_binding: index.zero? ? browser_binding : nil,
      )
    end
    device_session&.revoke!(reason: reason)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed, ActiveRecord::StatementInvalid,
         ActiveRecord::ConnectionNotDefined => e
    Rails.logger.warn(
      JitLogEvent.format(
        "auth.logout_current_session.device_session_failed",
        reason: reason,
        resource_class: resource&.class&.name,
        token_class: token_record&.class&.name,
        error_class: e.class.name,
      ),
    )
    # A failed stop must remain observable; a partial sign-out never reports success.
    raise
  end

  def stop_roots_for(token_record, device_session)
    roots = []
    roots << token_record if op_root?(token_record)
    if device_session && cascade_device_session_tokens
      root_class = op_root?(token_record) ? token_record.class : token_class
      if op_root_class?(root_class)
        root_class.where(device_session_id: device_session.id).order(:id).each do |sibling|
          roots << sibling unless roots.any? { |root| root.id == sibling.id }
        end
      end
    end
    roots
  end

  def op_root?(record) = record.present? && op_root_class?(record.class)

  def op_root_class?(klass) = [ClientToken, VisitorToken, OperatorToken].include?(klass)

  # D-123: the stop names its principal; one that cannot be established is refused by the primitive.
  def principal_public_id_for(root)
    actor = root.respond_to?(:actor_record) ? root.actor_record : nil
    actor ||= resource
    actor.respond_to?(:public_id) ? actor.public_id.to_s : ""
  end

  def device_session_for_token(token_record)
    case token_record
    when ClientToken, VisitorToken, OperatorToken
      token_record.device_session_record
    end
  end
end
