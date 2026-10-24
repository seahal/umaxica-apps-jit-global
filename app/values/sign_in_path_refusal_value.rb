# typed: false
# frozen_string_literal: true

# WU-07 (D-73): the closed catalogue of Sign-in path refusal reasons, each in exactly one class. The
# class decides the response; the reason only names the event in server logs.
class SignInPathRefusalValue
  CLASSES = %i(ownership_mismatch retryable definitive dependency internal protocol).freeze
  RESPONSES = {
    ownership_mismatch: :bad_request,
    definitive: :bad_request,
    dependency: :service_unavailable,
    internal: :internal_server_error,
  }.freeze
  REASONS = {
    "ownership_mismatch" => :ownership_mismatch,
    "foreign_browser" => :ownership_mismatch,
    "wrong_binding" => :ownership_mismatch,
    "missing_binding" => :ownership_mismatch,
    "surface_mismatch" => :ownership_mismatch,
    "flow_not_found" => :ownership_mismatch,
    "flow_mismatch" => :ownership_mismatch,
    "actor_mismatch" => :ownership_mismatch,
    "phase_mismatch" => :ownership_mismatch,
    "phase_violation" => :definitive,
    "phase_regression" => :definitive,
    "turnstile_failed" => :retryable,
    "invalid_input" => :retryable,
    "sentry_blocked" => :retryable,
    "curfew_passed" => :definitive,
    "transaction_missing" => :definitive,
    "intent_crossing" => :definitive,
    "subject_enforced" => :definitive,
    "evidence_consumed" => :definitive,
    "not_on_first_page" => :definitive,
    "exit_unavailable" => :definitive,
    "credential_failed" => :definitive,
    "state_expired" => :definitive,
    "state_invalid" => :definitive,
    "store_unavailable" => :dependency,
    "database_unavailable" => :dependency,
    "provider_failed" => :dependency,
    "provider_unavailable" => :dependency,
    "invariant_broken" => :internal,
    "identity_without_client" => :internal,
    "oidc_access_denied" => :protocol,
    "login_required" => :protocol,
    "token_exchange_failed" => :protocol,
    "revocation_failed" => :protocol,
  }.freeze

  attr_reader :reason, :refusal_class

  class << self
    public

    def for(reason)
      new(reason.to_s)
    end
  end

  public

  def initialize(reason)
    @refusal_class = REASONS.fetch(reason) { raise ArgumentError, "unknown sign-in path refusal reason" }
    @reason = reason
    freeze
  end

  # Retryable and protocol refusals answer through their own page or the OIDC redirect, not here.
  def status
    RESPONSES.fetch(refusal_class) { raise ArgumentError, "#{refusal_class} refusals are not rendered here" }
  end

  def clears_continuity?
    %i(ownership_mismatch definitive).include?(refusal_class)
  end

  def retryable?
    refusal_class == :retryable
  end

  def protocol?
    refusal_class == :protocol
  end
end
