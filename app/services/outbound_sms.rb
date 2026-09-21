# typed: false
# frozen_string_literal: true

class OutboundSms < ApplicationService
  PROVIDERS = {
    "aws_sns" => OutboundSmsProvidersAwsSns,
    "test" => OutboundSmsProvidersTest,
  }.freeze

  SUSPENDED_ERROR = "outbound sms channel is suspended"

  def self.deliver_now(to:, title:, body:)
    return suspended_result if suspended?

    response = provider.send_message(to: to, title: title, body: body)
    record_delivery_event_safely(
      "provider_accepted",
      metadata: provider_acceptance_metadata(response),
    )
    response
  rescue StandardError => e
    record_delivery_event_safely("delivery_failed", reason: e.class.name)
    raise
  end

  def self.deliver_later(to:, title:, body:)
    return suspended_result if suspended?

    provider
    Outbound::SmsDeliveryJob.perform_later(
      encrypted_payload: OutboundSensitivePayload.encrypt_sms_delivery(to:, title:, body:),
    )
    record_delivery_event_safely("enqueued")
    OutboundResult.accepted(channel: :sms)
  rescue StandardError => e
    record_delivery_event_safely("enqueue_failed", reason: e.class.name)
    raise
  end

  def self.suspended?
    OutboundChannelSuspension.suspended?(:sms)
  end

  # The recipient is not logged: the outcome and the channel are what an operator needs
  # while the kill switch is pulled.
  def self.suspended_result
    record_delivery_event_safely("suspended", reason: SUSPENDED_ERROR)
    Rails.logger.warn(JitLogEvent.format("outbound.sms.suspended", channel: "sms"))
    OutboundResult.rejected(channel: :sms, error: SUSPENDED_ERROR)
  end

  def self.provider
    provider_name = Rails.application.config.sms_provider.to_s
    provider_class =
      PROVIDERS.fetch(provider_name) do
        raise ArgumentError, "Unknown SMS provider: #{provider_name}"
      end

    provider_class.new
  end

  def self.record_delivery_event_safely(event, metadata: {}, reason: nil)
    Chronicle.capture(
      action: "notification.delivery.sms.#{event}",
      reason: reason,
      metadata: metadata.compact,
    )
  rescue StandardError => e
    Rails.logger.error(
      JitLogEvent.format(
        "notification.delivery_audit_failed",
        action: "notification.delivery.sms.#{event}",
        error_class: e.class.name,
      ),
    )
    nil
  end

  def self.provider_acceptance_metadata(response)
    return {} unless response.respond_to?(:provider)

    {
      provider: response.provider,
      provider_reference: response.provider_reference,
      accepted_at: response.accepted_at&.iso8601,
    }
  rescue StandardError
    {}
  end

  private_class_method :record_delivery_event_safely
  private_class_method :provider_acceptance_metadata

  def initialize(to:, title:, body:, **options)
    super()
    @to = to
    @title = title
    @body = body
    @options = options
  end

  def call
    self.class.deliver_later(to: to, title: title, body: body)
  end

  private

  attr_reader :to, :title, :body, :options
end
