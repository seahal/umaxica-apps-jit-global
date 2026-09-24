# typed: false
# frozen_string_literal: true

class ProcessorErasureNotificationAdapter
  public

  def retry_policy
    raise NotImplementedError, "processor adapter must expose a finite retry policy"
  end

  def dispatch(notification:, attempt:)
    raise NotImplementedError, "processor adapter must implement dispatch"
  end

  def verify_receipt(notification:, raw_receipt:)
    raise NotImplementedError, "processor adapter must verify and normalize receipts"
  end
end
