# typed: false
# frozen_string_literal: true

class SignInSequence
  STATES = %w(
    STARTED
    PRIMARY_VERIFIED
    MFA_PENDING
    SESSION_LIMIT_PENDING
    GUARDRAIL_PENDING
    SESSION_ISSUED
    CHECKPOINT_PENDING
    DASHBOARD_PENDING
    COMPLETED
    FAILED
    EXPIRED
    HALTED
  ).freeze

  PARTICIPANTS = %w(guardrail checkpoint dashboard).freeze
  TERMINAL_STATES = %w(COMPLETED FAILED EXPIRED HALTED).freeze

  attr_reader :payload

  def self.missing
    new({})
  end

  def initialize(payload)
    @payload = payload.to_h.stringify_keys
  end

  delegate :blank?, to: :id

  delegate :present?, to: :id

  def id = payload["id"]

  def surface = payload["surface"]

  def actor_type = payload["actor_type"]

  def actor_id = payload["actor_id"]

  def method = payload["method"]

  def state = payload["state"]

  def participant = payload["participant"]

  def pt = payload["pt"]

  def safe_pt_path = payload["safe_pt_path"] || payload["safe_return_path"] || payload["pt"]

  def mfa_challenge_id = payload["mfa_challenge_id"]

  def session_limit_gate_id = payload["session_limit_gate_id"]

  def restricted_login_public_id = payload["restricted_login_public_id"]

  def terminal_state = payload["terminal_state"]

  def created_at = parse_time(payload["created_at"])

  def updated_at = parse_time(payload["updated_at"])

  def expires_at
    parse_time(payload["expires_at"])
  end

  def expired?
    expires_at.blank? || Time.current >= expires_at
  end

  def terminal?
    terminal_state.present? || TERMINAL_STATES.include?(state.to_s)
  end

  def valid_for?(surface:, actor:, participant:)
    return false if blank?
    return false if expired?
    return false if terminal?
    return false unless self.surface == surface.to_s
    return false unless self.participant == participant.to_s

    actor_matches?(actor)
  end

  def actor_matches?(actor)
    return false if actor.blank?

    actor.class.name == actor_type && actor.id.to_s == actor_id.to_s
  end

  private

  def parse_time(raw)
    return nil if raw.blank?

    Time.zone.parse(raw.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
