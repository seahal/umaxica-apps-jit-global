# frozen_string_literal: true

class StepUpAuditCodesRegistry
  EVENT_TYPES = %w(
    step_up.requested step_up.committed step_up.installed step_up.cancelled step_up.expired step_up.failed
    step_up.refused step_up.indeterminate step_up.attempt_rejected sensitive_admission.closed
  ).freeze

  REASON_CODES = %w(
    requested dispatch_started completed user_cancelled expired binding_mismatch expectation_mismatch
    policy_refused unsatisfiable_class op_error generation_superseded session_invalid exchange_timeout
    dispatch_deadline_passed foreign_browser state_mismatch duplicate_callback
  ).freeze

  METHODS = %w(passkey totp email_otp).freeze
  FAILED_CODES = %w(binding_mismatch expectation_mismatch policy_refused unsatisfiable_class).freeze
  REFUSED_OR_INDETERMINATE_CODES = %w(
    op_error generation_superseded session_invalid exchange_timeout dispatch_deadline_passed
  ).freeze
  REJECTED_CODES = %w(foreign_browser state_mismatch duplicate_callback).freeze
  DELIVERY_FAILURE_CODES = %w(
    none chronicle_unavailable retention_policy_missing event_identity_conflict chronicle_record_invalid delivery_failed
  ).freeze

  PAYLOAD_KEYS_BY_EVENT = {
    "sensitive_admission.closed" => %w(admission_ref).freeze,
    "step_up.requested" => %w(rp_state_ref return_target_kind).freeze,
    "step_up.committed" => %w(op_context_ref grant_ref verified_method auth_time).freeze,
    "step_up.installed" => %w(rp_state_ref grant_ref installed_generation).freeze,
    "step_up.failed" => %w(op_context_ref failure_code).freeze,
    "step_up.refused" => %w(rp_state_ref failure_code).freeze,
    "step_up.indeterminate" => %w(rp_state_ref failure_code).freeze,
    "step_up.attempt_rejected" => %w(context_ref rejection_code).freeze,
  }.freeze
  CANCELLATION_PAYLOAD_EVENTS = %w(step_up.cancelled step_up.expired).freeze
  CANCELLATION_PAYLOAD_KEYS = %w(op_context_ref rp_state_ref).freeze
  PAYLOAD_CODE_RULES = {
    "step_up.failed" => ["failure_code", FAILED_CODES].freeze,
    "step_up.refused" => ["failure_code", REFUSED_OR_INDETERMINATE_CODES].freeze,
    "step_up.indeterminate" => ["failure_code", REFUSED_OR_INDETERMINATE_CODES].freeze,
    "step_up.attempt_rejected" => ["rejection_code", REJECTED_CODES].freeze,
  }.freeze

  class << self
    public

    def valid_payload?(event_type:, payload:)
      return false unless EVENT_TYPES.include?(event_type)
      return false unless payload.is_a?(Hash)

      stringified_keys = payload.keys.map(&:to_s)
      return false unless stringified_keys.uniq == stringified_keys

      if CANCELLATION_PAYLOAD_EVENTS.include?(event_type)
        return false unless CANCELLATION_PAYLOAD_KEYS.include?(stringified_keys.first)
        return false unless stringified_keys.length == 1
      else
        return false unless PAYLOAD_KEYS_BY_EVENT.fetch(event_type).sort == stringified_keys.sort
      end

      return false unless payload.values.all? { |value| value.is_a?(String) || value.is_a?(Integer) }
      return false unless payload.values.none? { |value| value.is_a?(String) && value.empty? }
      return false unless valid_payload_code?(event_type:, payload:)

      valid_event_values?(event_type:, payload:)
    end

    def valid_payload_code?(event_type:, payload:)
      rule = PAYLOAD_CODE_RULES[event_type]
      return true unless rule

      key, allowed_codes = rule
      code = payload.is_a?(Hash) ? (payload[key] || payload[key.to_sym]) : nil
      allowed_codes.include?(code)
    end

    private

    def valid_event_values?(event_type:, payload:)
      case event_type
      when "sensitive_admission.closed"
        reference?(payload[:admission_ref] || payload["admission_ref"])
      when "step_up.requested"
        valid_requested_payload?(payload)
      when "step_up.committed"
        valid_committed_payload?(payload)
      when "step_up.installed"
        valid_installed_payload?(payload)
      when "step_up.cancelled", "step_up.expired"
        reference?(payload.values.first)
      when "step_up.failed", "step_up.refused", "step_up.indeterminate", "step_up.attempt_rejected"
        valid_reference_outcome_payload?(payload)
      else
        raise ArgumentError, "unsupported step-up event type: #{event_type.inspect}"
      end
    end

    def valid_requested_payload?(payload)
      reference?(payload[:rp_state_ref] || payload["rp_state_ref"]) &&
        (payload[:return_target_kind] || payload["return_target_kind"]) == "relative"
    end

    def valid_committed_payload?(payload)
      reference?(payload[:op_context_ref] || payload["op_context_ref"]) &&
        reference?(payload[:grant_ref] || payload["grant_ref"]) &&
        METHODS.include?(payload[:verified_method] || payload["verified_method"]) &&
        nonnegative_integer?(payload[:auth_time] || payload["auth_time"])
    end

    def valid_installed_payload?(payload)
      reference?(payload[:rp_state_ref] || payload["rp_state_ref"]) &&
        reference?(payload[:grant_ref] || payload["grant_ref"]) &&
        nonnegative_integer?(payload[:installed_generation] || payload["installed_generation"])
    end

    def valid_reference_outcome_payload?(payload)
      payload.any? do |key, value|
        %w(failure_code rejection_code).exclude?(key.to_s) && reference?(value)
      end
    end

    def reference?(value)
      value.is_a?(String) && value.length == 21
    end

    def nonnegative_integer?(value)
      value.is_a?(Integer) && value >= 0
    end
  end
end
