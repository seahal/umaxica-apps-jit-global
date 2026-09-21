# typed: false
# frozen_string_literal: true

class SignInSessionLimitManager
  class Error < StandardError; end

  class InvalidCycle < Error; end

  class ActorMismatch < Error; end

  class TokenMismatch < Error; end

  class PromotionBlocked < Error; end

  SignInResult = Struct.new(:cycle, :token, :refresh_token, keyword_init: true)

  SURFACES = {
    ClientSignInFlow => {
      actor_class: Client,
      token_class: ClientToken,
      foreign_key: :user_id,
      max_active_sessions: ClientToken::MAX_SESSIONS_PER_USER,
    },
    VisitorSignInFlow => {
      actor_class: Visitor,
      token_class: VisitorToken,
      foreign_key: :visitor_id,
      max_active_sessions: VisitorToken::MAX_SESSIONS_PER_VISITOR,
    },
    OperatorSignInFlow => {
      actor_class: Operator,
      token_class: OperatorToken,
      foreign_key: :staff_id,
      max_active_sessions: OperatorToken::MAX_SESSIONS_PER_STAFF,
    },
  }.freeze

  def initialize(cycle:, actor:, token: nil, dpop_jkt: nil)
    @cycle = cycle
    @actor = actor
    @token = token
    @dpop_jkt = dpop_jkt
  end

  def issue_restricted!
    metadata = surface_metadata
    ensure_actor_class!(metadata)

    cycle.class.transaction do
      cycle.lock!
      ensure_session_limit_cycle!
      ensure_actor_binding!
      raise InvalidCycle, "sign-in cycle already has a restricted token" if cycle.token_id.present?

      restricted_token = create_restricted_token!(metadata)
      refresh_token = restricted_token.rotate_refresh_token!(discard_at: restricted_expires_at)
      cycle.update!(token: restricted_token)

      SignInResult.new(cycle: cycle, token: restricted_token, refresh_token: refresh_token)
    end
  end

  def promote!
    metadata = surface_metadata
    ensure_actor_class!(metadata)

    cycle.class.transaction do
      cycle.lock!
      ensure_session_limit_cycle!
      ensure_actor_binding!
      raise PromotionBlocked, "active session limit is still full" unless can_promote?(metadata)

      cycle.advance_sign_in_to_guardrail!

      SignInResult.new(cycle: cycle, token: nil, refresh_token: nil)
    end
  end

  def cancel!
    metadata = surface_metadata
    ensure_actor_class!(metadata)

    cycle.class.transaction do
      cycle.lock!
      ensure_session_limit_cycle!
      ensure_actor_binding!
      locked_restricted_token!(metadata)&.revoke! if cycle.token_id.present?
      cycle.fail_sign_in!

      SignInResult.new(cycle: cycle, token: nil, refresh_token: nil)
    end
  end

  private

  attr_reader :cycle, :actor, :token, :dpop_jkt

  def surface_metadata
    SURFACES.fetch(cycle.class) { raise InvalidCycle, "unsupported sign-in cycle" }
  end

  def ensure_actor_class!(metadata)
    return if actor.is_a?(metadata.fetch(:actor_class))

    raise ActorMismatch, "actor does not match sign-in cycle surface"
  end

  def ensure_session_limit_cycle!
    raise InvalidCycle,
          "sign-in cycle is not pending session-limit handling" unless cycle.sign_in_session_limit_pending?
    raise InvalidCycle, "sign-in cycle is expired" if cycle.expired?
  end

  def ensure_actor_binding!
    raise InvalidCycle, "sign-in cycle is not bound to an actor" if cycle.principal_id.blank?
    raise ActorMismatch, "actor does not match sign-in cycle" unless cycle.principal_id == actor.id
  end

  def create_restricted_token!(metadata)
    token_class = metadata.fetch(:token_class)
    ensure_reference_defaults!(token_class)

    attrs = {
      metadata.fetch(:foreign_key) => actor.id,
      token_class.token_status_foreign_key => token_class.token_status_model::RESTRICTED,
    }
    attrs[:dpop_jkt] = dpop_jkt if dpop_jkt.present?

    token_class.create!(attrs)
  end

  def locked_restricted_token!(metadata)
    restricted_token = locked_bound_token(metadata)
    raise InvalidCycle, "sign-in cycle is not bound to a token" unless restricted_token
    raise TokenMismatch, "current token does not match sign-in cycle" unless token&.id == restricted_token.id
    raise TokenMismatch, "sign-in cycle token is not restricted" unless restricted_token.restricted?

    restricted_token
  end

  def locked_bound_token(metadata)
    return nil if cycle.token_id.blank?

    metadata.fetch(:token_class).lock.find_by(id: cycle.token_id)
  end

  def can_promote?(metadata)
    token_class = metadata.fetch(:token_class)
    foreign_key = metadata.fetch(:foreign_key)

    token_class.active_status.where(foreign_key => actor.id).count < metadata.fetch(:max_active_sessions)
  end

  def restricted_expires_at
    Time.current + TokenStatusManagement::RESTRICTED_TTL
  end

  def ensure_reference_defaults!(token_class)
    reference_models_for(token_class).each do |model|
      model.ensure_defaults! if model.respond_to?(:ensure_defaults!)
    end
  end

  def reference_models_for(token_class)
    case token_class.name
    when "ClientToken"
      [ClientTokenStatus, ClientTokenKind, ClientTokenBindingMethod, ClientTokenDbscStatus]
    when "VisitorToken"
      [VisitorTokenStatus, VisitorTokenKind, VisitorTokenBindingMethod, VisitorTokenDbscStatus]
    when "OperatorToken"
      [OperatorTokenStatus, OperatorTokenKind, OperatorTokenBindingMethod, OperatorTokenDbscStatus]
    else
      []
    end
  end
end
