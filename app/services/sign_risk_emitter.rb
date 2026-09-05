# typed: false
# frozen_string_literal: true

class SignRiskEmitter
  # Risk events are audit-grade data and stay in PostgreSQL; they are not moved to
  # the rate-limit Valkey store, which holds no durable application state.
  # TODO: the synchronous INSERT (~1-3ms) sits on the auth request path. If p99
  #   latency becomes a concern, move the write to a SolidQueue job. Monitor
  #   occurrence DB write times in production.

  def self.emit(name, **payload)
    return unless feature_enabled?

    event = SignRiskEvent.new(name, payload: payload)
    persist(event)
  end

  def self.persist(event)
    user_id = event.payload[:user_id]
    staff_id = event.payload[:staff_id]
    visitor_id = event.payload[:visitor_id]
    return unless user_id || staff_id || visitor_id

    context = build_context(event)

    if staff_id
      persist_staff_occurrence(event, staff_id, context)
    elsif visitor_id
      persist_visitor_occurrence(event, visitor_id, context)
    else
      persist_user_occurrence(event, user_id, context)
    end
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error(
      JitLogEvent.format(
        "sign.risk.emitter.persist_failed",
        error_class: e.class.name,
        message: e.message,
        event_name: event.name,
      ),
    )
  end

  def self.build_context(event)
    {
      email_hmac: hmac_email(event.payload[:email]),
      ip_hmac: hmac_ip(event.payload[:ip]),
      reason: event.payload[:reason] || meta_reason(event.payload[:meta]),
      request_id: event.payload[:request_id],
      user_agent: event.payload[:user_agent],
      occurred_at: event.occurred_at.iso8601,
    }.compact
  end

  def self.persist_user_occurrence(event, user_id, context)
    expiry = 1.hour.from_now
    operation =
      -> do
        ClientOccurrence.create!(
          body: SecureRandom.uuid,
          event_type: "risk.#{event.name}",
          context: context.merge(user_id: user_id),
          status_id: ClientOccurrenceStatus::ACTIVE,
          discarded_at: expiry,
          purged_at: expiry,
        )
      end
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  def self.persist_visitor_occurrence(event, visitor_id, context)
    expiry = 1.hour.from_now
    operation =
      -> do
        VisitorOccurrence.create!(
          body: SecureRandom.uuid,
          event_type: "risk.#{event.name}",
          context: context.merge(visitor_id: visitor_id),
          status_id: VisitorOccurrenceStatus::ACTIVE,
          discarded_at: expiry,
          purged_at: expiry,
        )
      end
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  def self.persist_staff_occurrence(event, staff_id, context)
    expiry = 1.hour.from_now
    operation =
      -> do
        OperatorOccurrence.create!(
          body: SecureRandom.uuid,
          event_type: "risk.#{event.name}",
          context: context.merge(staff_id: staff_id),
          status_id: OperatorOccurrenceStatus::ACTIVE,
          discarded_at: expiry,
          purged_at: expiry,
        )
      end
    defined?(Prosopite) ? Prosopite.pause(&operation) : operation.call
  end

  def self.feature_enabled?
    return false if ENV["RISK_ENFORCEMENT_DISABLED"] == "true"

    enabled_config = Rails.configuration.try(:x).try(:risk_enforcement).try(:enabled)
    enabled_config || ENV["RISK_ENFORCEMENT_ENABLED"] == "true" || Rails.env.production?
  end

  def self.hmac_email(email)
    return if email.blank?

    OccurrenceHmac.email_hmac(email)
  rescue OccurrenceHmac::MissingSecretError
    nil
  end

  def self.hmac_ip(ip)
    return if ip.blank?

    OccurrenceHmac.ip_hmac(ip)
  rescue OccurrenceHmac::MissingSecretError
    nil
  end

  def self.meta_reason(meta)
    return unless meta.respond_to?(:[])

    meta[:reason] || meta["reason"]
  end

  private_class_method :persist, :build_context, :persist_user_occurrence, :persist_visitor_occurrence,
                       :persist_staff_occurrence, :hmac_email, :hmac_ip, :meta_reason
end
