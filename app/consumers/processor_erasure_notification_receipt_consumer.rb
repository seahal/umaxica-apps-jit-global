# typed: false
# frozen_string_literal: true

class ProcessorErasureNotificationReceiptConsumer
  class << self
    public

    def call(surface:, public_id:, raw_receipt:)
      new(surface:, public_id:, raw_receipt:).call
    end
  end

  public

  def initialize(surface:, public_id:, raw_receipt:)
    @surface = surface
    @public_id = public_id
    @raw_receipt = raw_receipt
  end

  def call
    notification = notification_class.find_by!(public_id: public_id)
    adapter = ProcessorErasureNotificationAdapterRegistry.fetch(notification.processor_key)
    raise ProcessorErasureNotificationReceiptError, "processor adapter is not configured" unless adapter

    receipt = adapter.verify_receipt(notification: notification, raw_receipt: raw_receipt)
    unless receipt.is_a?(ProcessorErasureVerifiedReceipt)
      raise ProcessorErasureNotificationReceiptError, "processor adapter returned an invalid receipt"
    end

    notification.apply_verified_receipt!(receipt: receipt)
  end

  private

  attr_reader :surface, :public_id, :raw_receipt

  def notification_class
    case surface.to_s
    when "app" then ClientProcessorErasureNotification
    when "com" then VisitorProcessorErasureNotification
    else raise ArgumentError, "unsupported processor erasure surface: #{surface.inspect}"
    end
  end
end
