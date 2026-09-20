# typed: false
# frozen_string_literal: true

class SignInStateMachine
  TERMINAL_RESULT_STATUSES = {
    session_limit_hard_reject: :forbidden,
    guardrail_blocked: :forbidden,
    login_forbidden: :forbidden,
    credential_failed: :unauthorized,
    invalid_request: :bad_request,
  }.freeze

  PRIMARY_VERIFIED_TRANSITIONS = {
    checkpoint: ["CHECKPOINT_PENDING", "checkpoint"],
    selector: ["SELECTOR_PENDING", "selector"],
  }.freeze

  def self.terminal_status?(status)
    TERMINAL_RESULT_STATUSES.key?(status.to_sym)
  end

  def self.http_status_for(status)
    TERMINAL_RESULT_STATUSES.fetch(status.to_sym)
  end
end
