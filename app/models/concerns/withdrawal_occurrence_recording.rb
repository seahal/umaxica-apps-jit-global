# typed: false
# frozen_string_literal: true

module WithdrawalOccurrenceRecording
  ALLOWED_CONTEXT_KEYS = %w(
    subject_type
    subject_public_id
    actor_type
    actor_public_id
    surface
    request_id
    session_public_id
    ceremony_public_id
    privacy_request_public_id
    retention_hold_public_id
    ip_occurrence_public_id
    user_agent_digest
    from_status
    to_status
    occurred_at
    reason_code
    retention_exception_code
    processor_key
    processor_notification_public_id
    delivery_generation
    delivery_attempt_number
  ).freeze

  def self.record!(subject:, event_type:, actor: nil, request: nil, context: {})
    occurrence_class = occurrence_class_for(subject)
    occurrence_status_class_for(occurrence_class).ensure_defaults!
    now = Time.current
    occurrence_class.create!(
      body: "wd-#{SecureRandom.hex(12)}",
      status_id: occurrence_status_id_for(occurrence_class),
      event_type: event_type.to_s,
      context: allowed_context(subject:, actor:, request:, occurred_at: now, context: context),
    )
  end

  def self.occurrence_class_for(subject)
    case subject
    when Client then ClientOccurrence
    when Visitor then VisitorOccurrence
    else
      raise ArgumentError, "unsupported withdrawal occurrence subject: #{subject.class.name}"
    end
  end

  def self.occurrence_status_id_for(occurrence_class)
    return ClientOccurrenceStatus::ACTIVE if occurrence_class == ClientOccurrence
    return VisitorOccurrenceStatus::ACTIVE if occurrence_class == VisitorOccurrence

    raise ArgumentError, "unsupported occurrence class: #{occurrence_class.name}"
  end

  def self.occurrence_status_class_for(occurrence_class)
    return ClientOccurrenceStatus if occurrence_class == ClientOccurrence
    return VisitorOccurrenceStatus if occurrence_class == VisitorOccurrence

    raise ArgumentError, "unsupported occurrence class: #{occurrence_class.name}"
  end

  def self.allowed_context(subject:, actor:, request:, occurred_at:, context:)
    base = {
      "subject_type" => subject.class.name,
      "subject_public_id" => subject.public_id.to_s,
      "actor_type" => actor&.class&.name.to_s,
      "actor_public_id" => actor&.try(:public_id).to_s,
      "surface" => surface_for(subject),
      "request_id" => request&.request_id.to_s,
      "user_agent_digest" => digest_optional(request&.user_agent),
      "occurred_at" => occurred_at.iso8601,
    }
    base.merge(context.transform_keys(&:to_s)).slice(*ALLOWED_CONTEXT_KEYS).compact_blank
  end

  def self.surface_for(subject)
    case subject
    when Client then "app"
    when Visitor then "com"
    else
      raise ArgumentError, "unsupported subject: #{subject.class.name}"
    end
  end

  def self.digest_optional(value)
    return nil if value.blank?

    Digest::SHA256.hexdigest(value.to_s)
  end
end
