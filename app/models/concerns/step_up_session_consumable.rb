# typed: false
# frozen_string_literal: true

module StepUpSessionConsumable
  extend ActiveSupport::Concern

  class_methods do
    # Runs the one-time completion work while holding the session row lock. A nil block result
    # leaves the row untouched; a successful result destroys the pending row before the transaction
    # commits. This keeps a concurrent worker from issuing a second step-up result.
    def consume_pending!(id:, now: Time.current)
      raise ArgumentError, "a completion block is required" unless block_given?

      result = nil
      transaction do
        locked = lock.find_by(id: id)
        if locked&.status == "PENDING" && locked.discard_at > now
          candidate = yield locked
          unless candidate.nil?
            locked.destroy!
            result = candidate
          end
        end
      end
      result
    end
  end
end
