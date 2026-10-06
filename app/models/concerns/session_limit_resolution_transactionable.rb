# typed: false
# frozen_string_literal: true

module SessionLimitResolutionTransactionable
  extend ActiveSupport::Concern

  PENDING = 10
  SESSION_SELECTED = 20
  RESOLVED = 100
  EXPIRED = 910
  CANCELLED = 920
  OPEN_STATES = [PENDING, SESSION_SELECTED].freeze
  TERMINAL_STATES = [RESOLVED, EXPIRED, CANCELLED].freeze
  TTL = 15.minutes

  TRANSITIONS = {
    PENDING => [SESSION_SELECTED, RESOLVED, EXPIRED, CANCELLED],
    SESSION_SELECTED => [RESOLVED, EXPIRED, CANCELLED],
    RESOLVED => [],
    EXPIRED => [],
    CANCELLED => [],
  }.freeze

  Issuance = Data.define(:transaction, :challenge)

  def self.model_for(actor)
    case actor
    when Client then ClientSessionLimitResolutionTransaction
    when Visitor then VisitorSessionLimitResolutionTransaction
    when Operator then OperatorSessionLimitResolutionTransaction
    else
      raise FlowConfigurationError, "unsupported session-limit resolution actor: #{actor.class.name}"
    end
  end

  included do
    self.belongs_to_required_by_default = false

    validates :state_id, :sign_in_flow_id, :actor_ref, :browser_binding_digest, :started_at, :expires_at,
              presence: true
    validates :challenge_digest, presence: true, uniqueness: true
    validates :state_id, inclusion: { in: TRANSITIONS.keys }
  end

  class_methods do
    def resolution_actor_class
      case name
      when "ClientSessionLimitResolutionTransaction" then Client
      when "VisitorSessionLimitResolutionTransaction" then Visitor
      when "OperatorSessionLimitResolutionTransaction" then Operator
      else
        raise FlowConfigurationError, "#{name} has no resolution actor class"
      end
    end

    def resolution_token_class
      case name
      when "ClientSessionLimitResolutionTransaction" then ClientToken
      when "VisitorSessionLimitResolutionTransaction" then VisitorToken
      when "OperatorSessionLimitResolutionTransaction" then OperatorToken
      else
        raise FlowConfigurationError, "#{name} has no resolution token class"
      end
    end

    def resolution_device_session_class
      case name
      when "ClientSessionLimitResolutionTransaction" then ClientDeviceSession
      when "VisitorSessionLimitResolutionTransaction" then VisitorDeviceSession
      when "OperatorSessionLimitResolutionTransaction" then OperatorDeviceSession
      else
        raise FlowConfigurationError, "#{name} has no resolution device-session class"
      end
    end

    def resolution_sign_in_flow_class
      case name
      when "ClientSessionLimitResolutionTransaction" then ClientSignInFlow
      when "VisitorSessionLimitResolutionTransaction" then VisitorSignInFlow
      when "OperatorSessionLimitResolutionTransaction" then OperatorSignInFlow
      else
        raise FlowConfigurationError, "#{name} has no resolution sign-in-flow class"
      end
    end

    def resolution_oidc_authorization_transaction_class
      case name
      when "ClientSessionLimitResolutionTransaction" then ClientOidcAuthorizationTransaction
      when "VisitorSessionLimitResolutionTransaction" then VisitorOidcAuthorizationTransaction
      when "OperatorSessionLimitResolutionTransaction" then OperatorOidcAuthorizationTransaction
      else
        raise FlowConfigurationError, "#{name} has no resolution authorization-transaction class"
      end
    end

    def resolution_state_class
      case name
      when "ClientSessionLimitResolutionTransaction" then ClientSessionLimitResolutionState
      when "VisitorSessionLimitResolutionTransaction" then VisitorSessionLimitResolutionState
      when "OperatorSessionLimitResolutionTransaction" then OperatorSessionLimitResolutionState
      else
        raise FlowConfigurationError, "#{name} has no resolution state class"
      end
    end

    def database_now
      lease_connection.select_value("SELECT CURRENT_TIMESTAMP").to_time
    end

    def open
      where(state_id: OPEN_STATES)
    end

    def active_at
      open.where(arel_table[:expires_at].gt(database_now))
    end

    def issue!(sign_in_flow:, actor:, browser_binding_digest:, oidc_authorization_transaction: nil,
               audit_context: {})
      oidc_authorization_transaction&.reload
      require_persisted_binding!(sign_in_flow, actor, browser_binding_digest, oidc_authorization_transaction)
      challenge = SecureRandom.urlsafe_base64(48)
      connection_class_for_self.connected_to(role: :writing) do
        writer_now = database_now
        transaction do
          sign_in_flow.with_lock do
            ensure_parent_open!(sign_in_flow, actor, writer_now)
            existing = open.where(sign_in_flow_id: sign_in_flow.id).lock.first
            if existing
              if existing.expires_at <= writer_now
                existing.update!(state_id: EXPIRED, expired_at: writer_now)
                existing.record_resolution_audit!("expired", actor: actor)
              else
                existing.update!(
                  challenge_digest: digest_challenge(challenge),
                  browser_binding_digest: browser_binding_digest,
                  expires_at: [existing.expires_at, sign_in_flow.expires_at].min,
                  audit_context: existing.audit_context.to_h.merge(audit_context.to_h.compact),
                )
                existing.record_resolution_audit!("issued", actor: actor)
                next Issuance.new(transaction: existing, challenge: challenge)
              end
            end

            record = create!(
              challenge_digest: digest_challenge(challenge),
              state_id: PENDING,
              sign_in_flow_id: sign_in_flow.id,
              oidc_authorization_transaction: oidc_authorization_transaction,
              actor_ref: actor.public_id,
              browser_binding_digest: browser_binding_digest,
              started_at: writer_now,
              expires_at: resolution_expiry(sign_in_flow, writer_now),
              audit_context: audit_context.to_h.compact,
            )
            record.record_resolution_audit!("issued", actor: actor)
            Issuance.new(transaction: record, challenge: challenge)
          end
        end
      end
    end

    def find_active_by_challenge(challenge)
      active_at.find_by(challenge_digest: digest_challenge(challenge))
    end

    def find_by_challenge(challenge)
      find_by(challenge_digest: digest_challenge(challenge))
    end

    def digest_challenge(challenge)
      OpenSSL::Digest::SHA256.hexdigest(challenge.to_s)
    end

    private

    def require_persisted_binding!(sign_in_flow, actor, browser_binding_digest, oidc_authorization_transaction)
      raise ArgumentError, "sign-in flow is required" unless sign_in_flow.is_a?(resolution_sign_in_flow_class)
      raise ArgumentError, "actor is required" unless actor.is_a?(resolution_actor_class)
      raise ArgumentError, "sign-in flow must be persisted" unless sign_in_flow.persisted?
      raise ArgumentError, "actor must be persisted" unless actor.persisted?
      raise ArgumentError, "browser binding digest is required" if browser_binding_digest.blank?
      if oidc_authorization_transaction &&
          !oidc_authorization_transaction.is_a?(resolution_oidc_authorization_transaction_class)
        raise ArgumentError, "authorization transaction belongs to another realm"
      end

      return unless oidc_authorization_transaction
      raise ArgumentError,
            "authorization transaction must be persisted" unless oidc_authorization_transaction.persisted?
      unless oidc_authorization_transaction.actor_ref == actor.public_id
        raise ArgumentError, "authorization transaction actor binding mismatch"
      end
      if oidc_authorization_transaction.respond_to?(:secret_sign_in_flow_id) &&
          oidc_authorization_transaction.secret_sign_in_flow_id.present? &&
          oidc_authorization_transaction.secret_sign_in_flow_id != sign_in_flow.id
        raise ArgumentError, "authorization transaction flow binding mismatch"
      end

    end

    def ensure_parent_open!(flow, actor, now)
      raise FlowInvalidTransition,
            "parent sign-in flow is expired" unless flow.cycle_accessible?(now) && !flow.expired?(now)
      raise FlowInvalidTransition, "parent sign-in flow is not bound to the actor" unless flow.principal_id == actor.id
      raise FlowInvalidTransition, "parent sign-in flow is not awaiting issuance" unless
        flow.sign_in_session_issuance_pending?
    end

    def resolution_expiry(flow, now)
      parent_expiry = flow.expires_at
      [parent_expiry, now + TTL].compact.min
    end
  end

  def pending?
    state_id == PENDING
  end

  def session_selected?
    state_id == SESSION_SELECTED
  end

  def resolved?
    state_id == RESOLVED
  end

  def expired?
    state_id == EXPIRED
  end

  def cancelled?
    state_id == CANCELLED
  end

  def open?
    OPEN_STATES.include?(state_id) && expires_at.present? && expires_at > self.class.database_now
  end

  def terminal?
    TERMINAL_STATES.include?(state_id)
  end

  def expired_at?
    expires_at.present? && expires_at <= self.class.database_now
  end

  def select_session!(actor:, challenge:, session_ref:, browser_binding_digest:)
    transition_with_resolution_lock!(
      SESSION_SELECTED, actor:, challenge:, browser_binding_digest:,
                        validate_same_state: true,
    ) do
      token = self.class.resolution_token_class.find_by(public_id: session_ref.to_s)
      unless token_owned_by_actor?(token, actor)
        raise FlowInvalidTransition, "selected session is not owned by the actor"
      end

      if session_selected?
        raise FlowInvalidTransition,
              "a different session is already selected" unless selected_session_ref == token.public_id

        next {}
      end
      raise FlowInvalidTransition, "selected session is not usable" unless token.currently_usable?

      { selected_session_ref: token.public_id, selected_at: self.class.database_now }
    end
  end

  def resolve!(actor:, challenge:, browser_binding_digest:)
    transition_with_resolution_lock!(RESOLVED, actor:, challenge:, browser_binding_digest:) do
      token = selected_token
      if token
        unless token_owned_by_actor?(token, actor)
          raise FlowInvalidTransition, "selected session is not owned by the actor"
        end

        result = AuthenticationSelectedSessionRevoker.call(
          owner: actor, token: token, reason: "session_limit_selected_revoke",
        )
        raise FlowInvalidTransition, "selected session could not be revoked" unless result.success?
      end

      { resolved_at: self.class.database_now }
    end
  end

  def cancel!(actor:, challenge:, browser_binding_digest:)
    transition_with_resolution_lock!(CANCELLED, actor:, challenge:, browser_binding_digest:) do
      { cancelled_at: self.class.database_now }
    end
  end

  def expire!
    actor = self.class.resolution_actor_class.find_by!(public_id: actor_ref)
    with_resolution_lock(actor:) do
      current = state_id
      next self if TERMINAL_STATES.include?(current)

      writer_now = self.class.database_now
      unless TRANSITIONS.fetch(current).include?(EXPIRED)
        raise FlowInvalidTransition, "invalid resolution expiry from #{current.inspect}"
      end

      update!(state_id: EXPIRED, expired_at: writer_now)
      record_resolution_audit!("expired", actor: self.class.resolution_actor_class.find_by!(public_id: actor_ref))
    end
  end

  private

  def transition_with_resolution_lock!(next_state, actor:, challenge:, browser_binding_digest:,
                                       validate_same_state: false)
    expired_during_transition = false
    result =
      with_resolution_lock(actor:) do
        writer_now = self.class.database_now
        ensure_resolution_binding!(actor, challenge, browser_binding_digest, writer_now)
        current = state_id
        # A retry of the exact terminal operation returns the stored outcome. A
        # terminal row is still immutable: a different operation, challenge,
        # actor, or browser binding never reopens it.
        if terminal?
          next self if current == next_state

          raise FlowInvalidTransition, "resolution is terminal"
        end
        if expired_at?
          update!(state_id: EXPIRED, expired_at: writer_now)
          record_resolution_audit!("expired", actor: actor)
          expired_during_transition = true
          next self
        end
        if current == next_state
          yield if validate_same_state
          next self
        end
        unless TRANSITIONS.fetch(current, []).include?(next_state)
          raise FlowInvalidTransition,
                "invalid resolution transition from #{current.inspect} to #{next_state.inspect}"
        end

        attributes = yield
        update!(attributes.merge(state_id: next_state))
        record_resolution_audit!(resolution_audit_operation(next_state), actor: actor)
      end
    raise FlowInvalidTransition, "resolution is expired" if expired_during_transition

    result
  end

  def with_resolution_lock(actor:)
    actor.class.connection_class_for_self.connected_to(role: :writing) do
      actor.with_lock do
        self.class.connection_class_for_self.connected_to(role: :writing) do
          authorization = oidc_authorization_transaction
          if authorization
            authorization.with_lock do
              lock_parent_and_resolution { yield }
            end
          else
            lock_parent_and_resolution { yield }
          end
        end
      end
    end
  end

  def lock_parent_and_resolution
    self.class.transaction do
      sign_in_flow.with_lock do
        lock!
        yield
      end
    end
  end

  def ensure_resolution_binding!(actor, challenge, binding_digest, _now)
    raise FlowInvalidTransition, "resolution binding mismatch" unless
      actor.is_a?(self.class.resolution_actor_class) && actor.public_id == actor_ref &&
        sign_in_flow.principal_id == actor.id &&
        binding_digest.present? && ActiveSupport::SecurityUtils.secure_compare(
          browser_binding_digest.to_s, binding_digest.to_s,
        ) && challenge_digest == self.class.digest_challenge(challenge)
  end

  def selected_token
    return if selected_session_ref.blank?

    self.class.resolution_token_class.find_by(public_id: selected_session_ref)
  end

  def token_owned_by_actor?(token, actor)
    return false unless token

    case token
    when ClientToken then token.user_id == actor.id
    when VisitorToken then token.visitor_id == actor.id
    when OperatorToken then token.staff_id == actor.id
    else false
    end
  end

  def resolution_audit_operation(next_state)
    case next_state
    when SESSION_SELECTED then "selected"
    when RESOLVED then "resolved"
    when CANCELLED then "cancelled"
    when EXPIRED then "expired"
    else
      raise FlowConfigurationError, "unsupported session-limit resolution audit state: #{next_state.inspect}"
    end
  end

  public

  def record_resolution_audit!(operation, actor:)
    audit_class =
      case actor
      when Client, Visitor then ClientChronicle
      when Operator then OperatorChronicle
      else
        raise FlowConfigurationError, "unsupported session-limit resolution actor: #{actor.class.name}"
      end
    event_id =
      case audit_class.name
      when "ClientChronicle" then ClientChronicleEvent::SESSION_REVOKED
      when "OperatorChronicle" then OperatorChronicleEvent::LOGGED_OUT
      else
        raise FlowConfigurationError, "unsupported session-limit resolution audit class: #{audit_class.name}"
      end
    AuthenticationAuditWriter.write(
      audit_class,
      event_id,
      resource: actor,
      actor: actor,
      context: {
        operation: "session_limit_resolution.#{operation}",
        resolution_transaction_id: id,
        sign_in_flow_id: sign_in_flow_id,
      }.merge(audit_context.to_h),
    )
  end
end
