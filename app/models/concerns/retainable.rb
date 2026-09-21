# typed: false
# frozen_string_literal: true

module Retainable
  extend ActiveSupport::Concern

  SENTINEL = ::Float::INFINITY

  # Models that include Retainable register themselves here. Used by the
  # `RetentionPurgeJob` allowlist test to assert that any new retainable
  # model is actually picked up by the worker -- forgetting to add a new
  # model leaves rows purgeable in principle but never purged in practice.
  REGISTRY = Concurrent::Array.new
  private_constant :REGISTRY

  class << self
    def registry
      REGISTRY
    end
  end

  included do
    attribute :discard_at, :datetime, default: -> { SENTINEL }
    attribute :purge_eligible_at, :datetime, default: -> { SENTINEL }

    validates :discard_at, presence: true
    validates :purge_eligible_at, presence: true
    validate :retention_order_valid
    validate :retention_times_not_before_created_at, on: :update

    Retainable.registry << self unless Retainable.registry.include?(self)
  end

  # NOTE: ActiveRecord scope intentionally omitted (conflicts with pre-existing
  #   `.active` / `.deletable` semantics). Use raw `where('discard_at > ?', Time.current)` for queries.

  def accessible?(now = Time.current)
    future_time?(discard_at, now)
  end

  def lapsed?(now = Time.current)
    !future_time?(discard_at, now)
  end

  def purgeable?(now = Time.current)
    !future_time?(purge_eligible_at, now)
  end

  # Schedule a future logical+physical deletion window. Both timestamps must be
  # in the future. Use this when scheduling retention up front (e.g. issuing a
  # token with a known expiry).
  def schedule_retention!(discard_at:, purge_eligible_at:)
    raise ArgumentError, "discard_at must be in the future" unless future_time?(discard_at)
    raise ArgumentError, "purge_eligible_at must be in the future" unless future_time?(purge_eligible_at)
    raise ArgumentError, "discard_at must be <= purge_eligible_at" if time_after?(discard_at, purge_eligible_at)

    update!(discard_at: discard_at, purge_eligible_at: purge_eligible_at)
  end

  # Mark as logically deleted *now* and schedule physical deletion after
  # `purge_after`. Use this for cancellation / expiration / failure paths where
  # the row stops being visible immediately and is eligible for purge later.
  #
  # `discard_at` clamps to `created_at` to satisfy the
  # `retention_times_not_before_created_at` invariant when the row was created
  # in the same request (Time.current may be less than created_at by us).
  def discard_now!(purge_after:, now: Time.current)
    raise ArgumentError, "purge_after must be a Duration" unless purge_after.respond_to?(:from_now)

    discard_at_value = persisted_created_at_or(now)
    purge_eligible_at_value = now + purge_after
    raise ArgumentError, "purge_eligible_at must be in the future" unless future_time?(purge_eligible_at_value, now)
    if time_after?(discard_at_value, purge_eligible_at_value)
      raise ArgumentError, "discard_at must be <= purge_eligible_at"
    end

    update!(discard_at: discard_at_value, purge_eligible_at: purge_eligible_at_value)
  end

  private

  def persisted_created_at_or(now)
    return now if created_at.blank?

    [created_at, now].max
  end

  def retention_order_valid
    return if discard_at.blank? || purge_eligible_at.blank?

    return unless time_after?(discard_at, purge_eligible_at)

    errors.add(:discard_at, "must be <= purge_eligible_at")
  end

  def retention_times_not_before_created_at
    return if created_at.blank?

    errors.add(:discard_at, "must be >= created_at") if time_before?(discard_at, created_at)
    errors.add(:purge_eligible_at, "must be >= created_at") if time_before?(purge_eligible_at, created_at)
  end

  def future_time?(value, now = Time.current)
    return true if positive_infinity?(value)
    return false if negative_infinity?(value)

    value.present? && value > now
  end

  def time_after?(left, right)
    return false if left.blank? || right.blank?
    return false if positive_infinity?(left) && positive_infinity?(right)
    return true if positive_infinity?(left)
    return false if negative_infinity?(left)
    return false if positive_infinity?(right)
    return true if negative_infinity?(right)

    left > right
  end

  def time_before?(left, right)
    return false if left.blank? || right.blank?
    return true if negative_infinity?(left)
    return false if positive_infinity?(left)
    return false if negative_infinity?(right)
    return true if positive_infinity?(right)

    left < right
  end

  def positive_infinity?(value)
    value.respond_to?(:infinite?) && value.infinite? == 1
  end

  def negative_infinity?(value)
    value.respond_to?(:infinite?) && value.infinite? == -1
  end
end
