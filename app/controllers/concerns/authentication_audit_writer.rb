# typed: false
# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength

# Writes auth-related Chronicle records (LOGGED_IN, LOGGED_OUT,
# LOGIN_FAILED, TOKEN_REFRESHED, ...) with a tiered guarantee:
#
#   1. Happy path: write the typed Chronicle row directly.
#   2. If that raises, persist a `ChronicleOutboxEntry` so a future
#      retry job (or operator) can recover the missing event.
#   3. If even the outbox write raises, hand off to
#      `ChronicleFallbackRecorder`, which renders a structured log
#      line that operators can grep for and replay manually.
#
# The `write` entry point preserves the original "do not block
# authentication on audit failure" contract: it returns true/false and
# never raises. The previous implementation only wrote a transient
# application log, with no durable record of the missing event. The
# outbox row brings the auth audit guarantee into
# line with what `Chronicle.capture` provides for higher-level chronicles.
# See S-4.
#
# Usage:
#   # Raises on failure (use only in critical paths)
#   AuthenticationAuditWriter.write!(audit_class, event_id, resource:, ...)
#
#   # Returns false on failure, populates outbox + telemetry. The
#   # default for auth flows.
#   AuthenticationAuditWriter.write(audit_class, event_id, resource:, ...)
class AuthenticationAuditWriter
  class AuditWriteError < StandardError; end

  WRITE_FAILED_EVENT = "authentication.audit.write_failed"
  OUTBOX_EVENT = WRITE_FAILED_EVENT
  FALLBACK_EVENT = "authentication.audit.write_failed.fallback"
  OUTBOX_UNAVAILABLE_EVENT = "authentication.audit.outbox_unavailable"
  OUTBOX_STATUS_PENDING = "pending"

  # Writes audit record and raises exception on failure
  # Use this when audit failure should stop the operation
  def self.write!(audit_class, event_id, resource:, actor: nil, ip_address: nil, context: {})
    actor ||= resource

    ChronicleRecord.connected_to(role: :writing) do
      normalized_event_id = normalize_event_id(audit_class, event_id)
      ensure_chronicle_references!(audit_class, normalized_event_id)
      audit = build_audit(
        audit_class, normalized_event_id, resource: resource, actor: actor,
                                          ip_address: ip_address, context: context,
      )

      unless audit.save
        error_message = "Audit save failed: #{audit.errors.full_messages.join(", ")}"
        raise AuditWriteError, error_message
      end

      audit
    end
  end

  # Writes audit record with best-effort semantics.
  # Returns true on success, false on failure.
  # Failures fall through to the chronicle outbox (and FallbackRecorder
  # as last resort). The caller is never raised on.
  def self.write(audit_class, event_id, resource:, actor: nil, ip_address: nil, context: {})
    write!(audit_class, event_id, resource: resource, actor: actor, ip_address: ip_address, context: context)
    true
  rescue StandardError => e
    event_uuid = SecureRandom.uuid
    actor ||= resource

    notify_write_failed(
      write_failed_payload(
        event_uuid: event_uuid, audit_class: audit_class, event_id: event_id,
        resource: resource, actor: actor, ip_address: ip_address, context: context,
        error: e,
      ),
    )

    enqueue_outbox_fallback!(
      event_uuid: event_uuid, audit_class: audit_class, event_id: event_id, resource: resource,
      actor: actor, ip_address: ip_address, context: context, error: e,
    )
    record_structured_fallback(
      event_uuid: event_uuid, event: FALLBACK_EVENT, event_id: event_id, resource: resource,
      actor: actor, error: e, manual_recovery_required: true,
    )

    false
  end

  # Builds audit record without saving
  def self.build_audit(audit_class, event_id, resource:, actor:, ip_address:, context: {})
    attributes = {
      actor: actor,
      event_id: event_id,
      occurred_at: Time.current,
    }
    attributes[:ip_address] = ip_address if ip_address.present?
    audit = audit_class.new(attributes)
    audit.context = context if context.present? && audit.respond_to?(:context=)

    if actor
      audit.actor_id = actor.id
      audit.actor_type = actor.class.name
    end

    # Set resource using the appropriate setter method
    # For ClientChronicle: user= or subject_id=/subject_type=
    # For OperatorChronicle: staff= or subject_id=/subject_type=
    resource_type = infer_resource_type(audit_class, resource)
    if audit.respond_to?("#{resource_type}=")
      audit.public_send("#{resource_type}=", resource)
    else
      # Fallback to subject_id/subject_type
      audit.subject_id = resource.id.to_s
      audit.subject_type = resource.class.name
    end

    audit
  end

  # Tier 2: persist a recovery record so the missed audit can be
  # replayed by a background job or by ops. Sanitises context before
  # writing -- the outbox row lives in the chronicle database and must
  # not embed secret_credentials.
  def self.enqueue_outbox_fallback!(event_uuid:, audit_class:, event_id:, resource:, actor:, ip_address:, context:,
                                    error:)
    payload = {
      audit_class: audit_class.name,
      event_id: event_id.to_s,
      resource_type: resource&.class&.name,
      resource_id: public_or_hmac_identifier(resource),
      actor_type: actor&.class&.name,
      actor_id: public_or_hmac_identifier(actor),
      ip_address: ip_address,
      context: ChronicleRecordPolicy.sanitize(context_hash(context)),
      error_class: error.class.name,
    }

    ChronicleRecord.connected_to(role: :writing) do
      ChronicleOutboxEntry.create!(
        event: OUTBOX_EVENT,
        event_uuid: event_uuid,
        payload: payload,
        status: OUTBOX_STATUS_PENDING,
      )
    end

    true
  rescue StandardError => e
    record_structured_fallback(
      event_uuid: event_uuid, event: OUTBOX_UNAVAILABLE_EVENT, event_id: event_id,
      resource: resource, actor: actor, error: e, manual_recovery_required: true,
    )

    false
  end

  # Infers resource type from audit class name
  # ClientChronicle -> "user", OperatorChronicle -> "staff"
  def self.infer_resource_type(audit_class, resource)
    # Try to extract from audit class name (ClientChronicle -> user)
    class_name = audit_class.name.demodulize
    if class_name =~ /^(\w+)Activity$/
      Regexp.last_match(1).downcase
    else
      # Fallback to resource class name
      resource.class.name.downcase
    end
  end

  private_class_method :infer_resource_type

  def self.write_failed_payload(event_uuid:, audit_class:, event_id:, resource:, actor:, ip_address:, context:,
                                error:)
    {
      event_uuid: event_uuid,
      audit_class: audit_class.name,
      event_id: event_id.to_s,
      resource_type: resource&.class&.name,
      resource_id: public_or_hmac_identifier(resource),
      actor_type: actor&.class&.name,
      actor_id: public_or_hmac_identifier(actor),
      ip_address_digest: hmac_identifier("ip_address", ip_address),
      context: ChronicleRecordPolicy.sanitize(context_hash(context)),
      error_class: error.class.name,
    }.compact
  end

  private_class_method :write_failed_payload

  def self.notify_write_failed(payload)
    Rails.logger.info(JitLogEvent.format(WRITE_FAILED_EVENT, payload))
  rescue StandardError
    false
  end

  private_class_method :notify_write_failed

  def self.context_hash(context)
    context.respond_to?(:to_h) ? context.to_h : {}
  end

  private_class_method :context_hash

  def self.record_structured_fallback(event_uuid:, event:, event_id:, resource:, actor:, error:,
                                      manual_recovery_required:)
    ChronicleFallbackRecorder.call(
      event: event,
      event_uuid: event_uuid,
      request_id: nil,
      action: event_id.to_s,
      actor: actor,
      subject: resource,
      error: error,
      manual_recovery_required: manual_recovery_required,
    )
  rescue StandardError
    false
  end

  private_class_method :record_structured_fallback

  def self.public_or_hmac_identifier(record)
    return if record.blank?

    public_id = record.public_id if record.respond_to?(:public_id)
    return public_id if public_id.present?

    hmac_identifier(record.class.name, record.id) if record.respond_to?(:id)
  end

  private_class_method :public_or_hmac_identifier

  def self.hmac_identifier(scope, value)
    return if value.blank?

    secret_credential = Rails.application.key_generator.generate_key("authentication-audit-writer/#{scope}", 32)
    OpenSSL::HMAC.hexdigest("SHA256", secret_credential, value.to_s)
  end

  private_class_method :hmac_identifier

  def self.normalize_event_id(audit_class, event_id)
    return event_id if event_id.is_a?(Integer)
    return event_id unless event_id.is_a?(String) || event_id.is_a?(Symbol)

    event_id_map_for(audit_class).fetch(event_id.to_s, event_id)
  end

  def self.event_id_map_for(audit_class)
    case audit_class.name
    when "ClientChronicle"
      {
        "LOGGED_IN" => ClientChronicleEvent::LOGGED_IN,
        "LOGGED_OUT" => ClientChronicleEvent::LOGGED_OUT,
        "LOGOUT" => ClientChronicleEvent::LOGOUT,
        "LOGIN_FAILED" => ClientChronicleEvent::LOGIN_FAILED,
        "TOKEN_REFRESHED" => ClientChronicleEvent::TOKEN_REFRESHED,
        "STEP_UP_FAILED" => ClientChronicleEvent::STEP_UP_FAILED,
        "REFRESH_TOKEN_REUSE_DETECTED" => ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED,
      }
    when "OperatorChronicle"
      {
        "LOGGED_IN" => OperatorChronicleEvent::LOGGED_IN,
        "LOGGED_OUT" => OperatorChronicleEvent::LOGGED_OUT,
        "LOGOUT" => OperatorChronicleEvent::LOGOUT,
        "LOGIN_FAILED" => OperatorChronicleEvent::LOGIN_FAILED,
        "TOKEN_REFRESHED" => OperatorChronicleEvent::TOKEN_REFRESHED,
        "STEP_UP_FAILED" => OperatorChronicleEvent::STEP_UP_FAILED,
        "REFRESH_TOKEN_REUSE_DETECTED" => OperatorChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED,
      }
    when "AppPreferenceChronicle"
      {
        "REFRESH_TOKEN_ROTATED" => AppPreferenceChronicleEvent::REFRESH_TOKEN_ROTATED,
        "UPDATE_PREFERENCE_COOKIE" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_COOKIE,
        "UPDATE_PREFERENCE_THEME" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_THEME,
        "RESET_BY_USER_DECISION" => AppPreferenceChronicleEvent::RESET_BY_USER_DECISION,
        "UPDATE_PREFERENCE_TIMEZONE" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_TIMEZONE,
        "UPDATE_PREFERENCE_REGION" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_REGION,
        "UPDATE_PREFERENCE_LANGUAGE" => AppPreferenceChronicleEvent::UPDATE_PREFERENCE_LANGUAGE,
        "CREATE_NEW_PREFERENCE_TOKEN" => AppPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
      }
    when "ComPreferenceChronicle"
      {
        "CREATE_NEW_PREFERENCE_TOKEN" => ComPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
        "REFRESH_TOKEN_ROTATED" => ComPreferenceChronicleEvent::REFRESH_TOKEN_ROTATED,
        "UPDATE_PREFERENCE_COOKIE" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_COOKIE,
        "UPDATE_PREFERENCE_LANGUAGE" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_LANGUAGE,
        "UPDATE_PREFERENCE_TIMEZONE" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_TIMEZONE,
        "RESET_BY_USER_DECISION" => ComPreferenceChronicleEvent::RESET_BY_USER_DECISION,
        "UPDATE_PREFERENCE_REGION" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_REGION,
        "UPDATE_PREFERENCE_THEME" => ComPreferenceChronicleEvent::UPDATE_PREFERENCE_THEME,
      }
    when "OrgPreferenceChronicle"
      {
        "CREATE_NEW_PREFERENCE_TOKEN" => OrgPreferenceChronicleEvent::CREATE_NEW_PREFERENCE_TOKEN,
        "REFRESH_TOKEN_ROTATED" => OrgPreferenceChronicleEvent::REFRESH_TOKEN_ROTATED,
        "UPDATE_PREFERENCE_COOKIE" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_COOKIE,
        "UPDATE_PREFERENCE_LANGUAGE" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_LANGUAGE,
        "UPDATE_PREFERENCE_TIMEZONE" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_TIMEZONE,
        "RESET_BY_USER_DECISION" => OrgPreferenceChronicleEvent::RESET_BY_USER_DECISION,
        "UPDATE_PREFERENCE_REGION" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_REGION,
        "UPDATE_PREFERENCE_THEME" => OrgPreferenceChronicleEvent::UPDATE_PREFERENCE_THEME,
      }
    else
      {}
    end
  end

  private_class_method :event_id_map_for

  def self.ensure_chronicle_references!(audit_class, event_id)
    operation =
      lambda do
        case audit_class.name
        when "ClientChronicle"
          return unless ClientChronicleEvent::DEFAULTS.include?(event_id)

          ClientChronicleEvent.find_or_create_by!(id: event_id)
          ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::NOTHING)
        when "OperatorChronicle"
          return unless OperatorChronicleEvent::DEFAULTS.include?(event_id)

          OperatorChronicleEvent.find_or_create_by!(id: event_id)
          OperatorChronicleLevel.find_or_create_by!(id: OperatorChronicleLevel::NOTHING)
        end
      end

    if defined?(Prosopite)
      Prosopite.pause(&operation)
    else
      operation.call
    end
  end

  private_class_method :ensure_chronicle_references!
  private_class_method :normalize_event_id
end

# rubocop:enable Metrics/MethodLength
