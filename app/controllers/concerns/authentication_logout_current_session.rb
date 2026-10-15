# typed: false
# frozen_string_literal: true

class AuthenticationLogoutCurrentSession
  class CommitOutcomeUnknown < StandardError; end

  class PreconditionFailed < StandardError; end

  def self.call(...)
    new(...).call
  end

  def initialize(current: nil, resource: nil, token: nil, token_class: nil, session_public_id: nil,
                 reason: "user_logout", cascade_device_session_tokens: true, precondition: nil)
    @current = current
    @resource = resource
    @token = token
    @token_class = token_class
    @session_public_id = session_public_id.presence || current_session_from_current
    @reason = reason
    @cascade_device_session_tokens = cascade_device_session_tokens
    @precondition = precondition
  end

  def call
    token_record = resolved_token
    return true if recent_completed_sign_out_flow?(token_record)

    with_token_writing_connection(token_record) do
      # An in-memory token is an internal legacy edge case: creating the flow
      # first persists its token association and establishes the expiry fields
      # needed by the token status callbacks. Persisted tokens follow the
      # lock-first order below so concurrent refresh cannot deadlock on the
      # flow's token foreign key.
      cycle = begin_sign_out_flow(token_record) unless token_record&.respond_to?(:persisted?) && token_record.persisted?
      begin
        verify_precondition_under_parent_lock!(token_record)
        revoke_device_session!(token_record)
        revoke_token!(token_record) unless device_session_cascade_handles_token?(token_record)
        # The parent/device hierarchy is locked before the SignOutFlow insert.
        # Its token foreign key otherwise takes a key-share lock first and can
        # deadlock with a concurrent RP refresh taking Device -> root -> RP.
        cycle ||= begin_sign_out_flow(token_record)
        cycle&.mark_access_discarded!
        cycle&.mark_logically_revoked!
        cycle&.complete_sign_out!
      rescue StandardError
        fail_sign_out_flow(cycle)
        raise
      end
    end
    true
  end

  private

  attr_reader :current, :resource, :token, :token_class, :session_public_id, :reason,
              :cascade_device_session_tokens, :precondition

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

  def revoke_device_session!(token_record)
    device_session = device_session_for_token(token_record) || find_device_session
    return if device_session.blank?

    revoke_browser_rp_sessions!(token_record)
    device_session.revoke!(reason: reason)
    return unless cascade_device_session_tokens

    if token_record&.class&.respond_to?(:where)
      token_record.class.where(device_session_id: device_session.id).find_each { |session_token|
        revoke_token!(session_token)
      }
    end
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
    # A failed parent revoke must remain observable. Revoking only the token
    # would leave the parent and its children in a contradictory state.
    raise
  end

  def revoke_browser_rp_sessions!(token_record)
    return if token_record.blank?
    return unless token_record.is_a?(ClientToken) ||
      token_record.is_a?(VisitorToken) || token_record.is_a?(OperatorToken)

    RpSessionRevoker.call(
      scope: :browser_session,
      record: token_record,
      status: "success",
      allow_missing_current_root: true,
    )
  end

  # Revocation either takes effect or raises. A row that is already gone is
  # the only failure that leaves nothing usable, so it is the only one treated
  # as done; any other failure must not let the sign-out flow complete.
  def revoke_token!(token_record)
    return true if token_record.blank?
    return true if token_record.respond_to?(:revoked?) && token_record.revoked?

    if token_record.respond_to?(:revoke!)
      token_record.revoke!
    elsif token_record.respond_to?(:destroy)
      raise ActiveRecord::RecordNotDestroyed.new("session token was not destroyed", token_record) unless
        token_record.destroy
    end
    true
  rescue ActiveRecord::RecordNotFound
    Rails.logger.info(
      JitLogEvent.format(
        "auth.logout_current_session.token_already_gone",
        reason: reason,
        resource_class: resource&.class&.name,
        token_class: token_record&.class&.name,
      ),
    )
    true
  end

  def device_session_for_token(token_record)
    case token_record
    when ClientToken, VisitorToken, OperatorToken
      token_record.device_session_record
    end
  end

  def device_session_cascade_handles_token?(token_record)
    cascade_device_session_tokens &&
      device_session_for_token(token_record).present?
  end

  def begin_sign_out_flow(token_record)
    cycle_class = sign_out_flow_class_for(token_record)
    return if cycle_class.blank?

    cycle_class.connection_class_for_self.connected_to(role: :writing) do
      cycle_class.create!(
        principal_id: sign_out_principal_id(token_record),
        token: token_record,
        kind_id: cycle_class.kind_id_for("IDP_SIGN_OUT"),
        refresh_token_family_id: sign_out_refresh_token_family_id(token_record),
        requested_at: Time.current,
        access_expires_at: Time.current,
        refresh_expires_at: sign_out_refresh_expires_at(token_record),
      )
    end
  rescue ActiveRecord::ActiveRecordError, ArgumentError => e
    Rails.logger.info(
      JitLogEvent.format(
        "auth.logout_current_session.cycle_unavailable",
        reason: reason,
        resource_class: resource&.class&.name,
        token_class: token_record&.class&.name,
        error_class: e.class.name,
      ),
    )
    raise
  end

  def recent_completed_sign_out_flow?(token_record)
    return false unless token_record&.respond_to?(:revoked?) && token_record.revoked?

    cycle_class = sign_out_flow_class_for(token_record)
    return false if cycle_class.blank?

    completed = cycle_class.where(token_id: token_record.id)
      .where(status_id: cycle_class.status_id_for("COMPLETED"))
      .where(cycle_class.arel_table[:completed_at].gt(5.minutes.ago))
      .exists?
    return false unless completed
    return false if unrevoked_browser_rp_sessions?(token_record)

    true
  rescue ActiveRecord::ActiveRecordError, ArgumentError
    false
  end

  def unrevoked_browser_rp_sessions?(token_record)
    owner = connection_owner_for(token_record.class)
    return false if owner.blank?

    owner.connected_to(role: :writing) do
      device_session = device_session_for_token(token_record)
      next false if device_session.blank?

      relation =
        case token_record
        when ClientToken then ClientRpSession
        when VisitorToken then VisitorRpSession
        when OperatorToken then OperatorRpSession
        else next false
        end
      relation.exists?(device_session_id: device_session.id, revoked_at: nil)
    end
  end

  def fail_sign_out_flow(cycle)
    return if cycle.blank? || cycle.sign_out_completed? || cycle.sign_out_failed?

    cycle.class.connection_class_for_self.connected_to(role: :writing) do
      cycle.reload.halt_sign_out!
    end
  rescue ActiveRecord::ActiveRecordError, FlowInvalidTransition
    nil
  end

  def sign_out_flow_class_for(token_record)
    case token_record
    when ClientToken then ClientSignOutFlow
    when VisitorToken then VisitorSignOutFlow
    when OperatorToken then OperatorSignOutFlow
    end
  end

  def sign_out_principal_id(token_record)
    return token_record.user_id if token_record.respond_to?(:user_id)
    return token_record.visitor_id if token_record.respond_to?(:visitor_id)
    return token_record.staff_id if token_record.respond_to?(:staff_id)

    resource&.id
  end

  def sign_out_refresh_token_family_id(token_record)
    token_record.refresh_token_family_id if token_record.respond_to?(:refresh_token_family_id)
  end

  def sign_out_refresh_expires_at(token_record)
    discard_at = token_record.discard_at if token_record.respond_to?(:discard_at)
    return 100.years.from_now if discard_at.respond_to?(:infinite?) && discard_at.infinite?
    return discard_at if discard_at.present? && discard_at > Time.current

    Time.current
  end
end
