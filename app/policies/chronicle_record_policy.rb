# typed: false
# frozen_string_literal: true

class ChronicleRecordPolicy
  FORBIDDEN_KEY_PATTERN =
    /
      password|passw|secret|secret_credential|raw_secret_credential|
      token|authorization|dpop|otp|totp|webauthn|recovery_code|
      cookie|raw_session|session_id\z|session\z|raw_email|raw_ip
    /ix
  ALLOWED_DIGEST_KEYS = %w(session_id_digest).freeze
  RESERVED_CONTEXT_KEYS = %w(request_id ip_address user_agent).freeze
  MAX_ERROR_MESSAGE_BYTES = 1.kilobyte
  SENSITIVE_VALUE_PATTERNS = [
    /bearer\s+[a-z0-9._~+\-\/]+=*/i,
    /\beyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\b/,
    /\b(?:password|passw|secret|secret_credential|token|otp|totp|recovery_code)\b\s*[:=]\s*\S+/i,
    /\b\d{6,8}\b/,
    /\b[a-zA-Z0-9_-]{32,}\b/,
  ].freeze

  RETENTION_POLICY_BY_ACTION = {
    "auth.sign_in.succeeded" => "ephemeral",
    "auth.sign_out.succeeded" => "ephemeral",
    "auth.sign_in.failed" => "security",
    "auth.step_up.succeeded" => "compliance",
    "auth.step_up.failed" => "compliance",
    "auth.aal.changed" => "compliance",
    "auth.session.revoked" => "compliance",
    "iam.role.assigned" => "compliance",
    "iam.role.revoked" => "compliance",
    "account.suspended" => "compliance",
    "account.terminated" => "compliance",
    "chronicle.audit_incomplete" => "compliance",
    "chronicle.manual_recovery_required" => "compliance",
  }.freeze

  PERMANENT_ACTION_PATTERNS = [
    /\Aaudit\.export\./,
    /\.deleted\z/,
    /\.destroyed\z/,
    /\.irreversible\z/,
  ].freeze

  SECURITY_ACTION_PATTERNS = [
    /\Arate_limit\./,
    /\Acsrf_detected\z/,
  ].freeze

  class << self
    def sanitize(value, key: nil)
      case value
      when Hash
        value.each_with_object({}) do |(child_key, entry), sanitized|
          next if forbidden_key?(child_key)

          sanitized[child_key.to_s] = sanitize(entry, key: child_key)
        end
      when Array
        value.map { |entry| sanitize(entry, key: key) }
      when String
        return value if safe_categorical_value?(value, key: key)

        sanitize_string(value)
      else
        value
      end
    end

    def sanitize_text(value)
      return if value.nil?

      sanitize_string(value.to_s)
    end

    def retention_policy_for(action:)
      code = retention_policy_code_for(action)
      ChronicleRetentionPolicy.find_by!(code: code)
    end

    def retention_policy_code_for(action)
      action_value = action.to_s
      return "permanent" if PERMANENT_ACTION_PATTERNS.any? { |pattern| pattern.match?(action_value) }
      return "security" if SECURITY_ACTION_PATTERNS.any? { |pattern| pattern.match?(action_value) }

      RETENTION_POLICY_BY_ACTION.fetch(action_value, "security")
    end

    def erasable_at_for(policy:, occurred_at:)
      return nil if policy.permanent?

      occurred_at + policy.duration_days.days
    end

    def actor_payload(actor)
      payload_for(actor, prefix: :actor)
    end

    def subject_payload(subject)
      payload_for(subject, prefix: :subject)
    end

    def log_payload(event:, event_uuid:, request_id:, action:, actor:, subject:, error: nil,
                    manual_recovery_required: false)
      actor_values = actor_payload(actor)
      subject_values = subject_payload(subject)

      {
        event: event,
        event_uuid: event_uuid,
        request_id: request_id,
        action: action,
        actor_type: actor_values[:actor_type],
        actor_id: actor_values[:actor_id],
        subject_type: subject_values[:subject_type],
        subject_id: subject_values[:subject_id],
        error_class: error&.class&.name,
        error_message: sanitize_error_message(error&.message),
        manual_recovery_required: manual_recovery_required,
      }
    end

    private

    def safe_categorical_value?(value, key:)
      key.to_s == "reason_code" && value.match?(/\A[a-z][a-z0-9_.-]{0,63}\z/)
    end

    def forbidden_key?(key)
      normalized = key.to_s.downcase
      return true if RESERVED_CONTEXT_KEYS.include?(normalized)
      return false if ALLOWED_DIGEST_KEYS.include?(normalized)

      FORBIDDEN_KEY_PATTERN.match?(normalized)
    end

    def sanitize_string(value)
      sanitized = value.dup
      SENSITIVE_VALUE_PATTERNS.each do |pattern|
        sanitized = sanitized.gsub(pattern, "[FILTERED]")
      end
      sanitized
    end

    def sanitize_error_message(value)
      return if value.blank?

      sanitized = sanitize_string(value.to_s)
      return sanitized if sanitized.bytesize <= MAX_ERROR_MESSAGE_BYTES

      sanitized.byteslice(0, MAX_ERROR_MESSAGE_BYTES).to_s
    end

    def payload_for(record, prefix:)
      return { "#{prefix}_type": nil, "#{prefix}_id": nil } if record.blank?

      identifier = record.public_id if record.respond_to?(:public_id)
      identifier = record.id if identifier.blank? && record.respond_to?(:id)

      {
        "#{prefix}_type": record.class.name,
        "#{prefix}_id": identifier,
      }
    end
  end
end
