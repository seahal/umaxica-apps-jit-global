# typed: false
# frozen_string_literal: true

# rubocop:disable ThreadSafety/ClassAndModuleAttributes

class FlowError < StandardError; end

class FlowConfigurationError < FlowError; end

class FlowInvalidTransition < FlowError; end

module FlowBase
  extend ActiveSupport::Concern

  included do
    class_attribute :cycle_status_column_name, instance_accessor: false
  end

  class_methods do
    def cycle_status_column(column_name)
      self.cycle_status_column_name = column_name.to_sym
    end
  end

  def cycle_status_id
    self[configured_cycle_status_column]
  end

  def cycle_status?(status_id)
    cycle_status_id == status_id
  end

  # The cycle_* predicates delegate to Retainable. Host classes are expected
  # to `include Retainable` (SignFlow does so for sign-up/in/out cycles).
  # Kept as named aliases so callers can use intent-revealing names within
  # the cycle namespace; new code may use `accessible?` / `purgeable?` /
  # `expired_or_lapsed?` directly.
  def cycle_accessible?(now = Time.current)
    retainable_required!(:accessible?)
    accessible?(now)
  end

  def discard_cycle!(discard_at: Time.current, purge_eligible_at:)
    with_cycle_lock do
      ensure_retention_order!(discard_at: discard_at, purge_eligible_at: purge_eligible_at)

      update!(discard_at: discard_at, purge_eligible_at: purge_eligible_at)
    end
  end

  # This is deliberately the only lifecycle status writer. Named operations
  # in the lifecycle concerns call it after deriving their destination from
  # the model's transition graph. It is private so callers cannot supply an
  # arbitrary source set or clock value.
  def transition_cycle_to!(next_status_id, changes: {}, timestamp_fields: [])
    expired_request = false

    with_cycle_lock do
      now = self.class.database_now
      current_status_id = cycle_status_id
      ensure_transition_auxiliary_fields!(changes, timestamp_fields)
      ensure_cycle_transition_known!(current_status_id, next_status_id)
      ensure_cycle_not_terminal!(current_status_id)
      raise FlowInvalidTransition, "cycle is discarded" unless cycle_accessible?(now)
      if next_status_id == cycle_status_id_for("EXPIRED") && !cycle_expires_at_lapsed?(now)
        raise FlowInvalidTransition, "cycle is not expired"
      end

      if cycle_expires_at_lapsed?(now)
        expire_status_id = cycle_status_id_for("EXPIRED")
        ensure_cycle_transition_known!(current_status_id, expire_status_id)
        update!(cycle_transition_attributes(expire_status_id, now, {}))
        expired_request = next_status_id != expire_status_id
      else
        update!(cycle_transition_attributes(next_status_id, now, changes, timestamp_fields: timestamp_fields))
      end
    end

    raise FlowInvalidTransition, "cycle is expired" if expired_request

    self
  end
  private :transition_cycle_to!

  # Pessimistic row lock for cycle mutations. `lock!` issues SELECT ... FOR
  # UPDATE which only holds the lock for the surrounding transaction; without
  # one, PostgreSQL releases the lock at statement end and the block runs
  # unprotected. Wrap in `self.class.transaction` so the lock is real whether
  # or not the caller already opened a transaction (Rails treats nested
  # `transaction` as a join, not a SAVEPOINT, unless `requires_new: true`).
  #
  # When a controller wraps the whole finalize sequence in `with_cycle_lock`
  # and the inner state-machine evaluation re-enters `with_cycle_lock` on the
  # same instance, the row is already locked for the outermost transaction.
  # Re-issuing SELECT ... FOR UPDATE is semantically redundant and only adds
  # round-trips, so the inner re-entry yields without re-locking.
  def with_cycle_lock
    raise ArgumentError, "block required" unless block_given?
    raise FlowInvalidTransition, "cycle must be persisted" unless persisted?

    return yield if @_in_cycle_lock

    self.class.connection_class_for_self.connected_to(role: :writing) do
      self.class.transaction do
        lock!
        @_in_cycle_lock = true
        begin
          yield
        ensure
          @_in_cycle_lock = false
        end
      end
    end
  end

  private

  def configured_cycle_status_column
    column = self.class.cycle_status_column_name
    raise FlowConfigurationError, "#{self.class.name} must configure cycle_status_column" if column.blank?

    ensure_cycle_column!(column)
    column
  end

  FORBIDDEN_TRANSITION_FIELDS = %i(
    status_id state_id state step issued_at expires_at discard_at purge_eligible_at
    completed_at failed_at cancelled_at
  ).freeze
  private_constant :FORBIDDEN_TRANSITION_FIELDS

  def ensure_transition_auxiliary_fields!(changes, _timestamp_fields)
    forbidden = changes.keys.map(&:to_sym) & FORBIDDEN_TRANSITION_FIELDS
    return if forbidden.empty?

    raise ArgumentError, "lifecycle fields are owned by the transition: #{forbidden.join(", ")}"
  end

  # Legacy lifecycle concerns outside the sign-flow family still carry their
  # own named source lists. Keep that validation private to the shared base;
  # SignFlow callers use the model transition graph through
  # `transition_cycle_to!` and cannot supply an arbitrary source list.
  def ensure_cycle_transition_allowed!(next_status_id, allowed_from:, now:)
    unless Array(allowed_from).include?(cycle_status_id)
      raise FlowInvalidTransition, "invalid transition from #{cycle_status_id.inspect} to #{next_status_id.inspect}"
    end

    raise FlowInvalidTransition, "cycle is discarded" unless cycle_accessible?(now)
    raise FlowInvalidTransition, "cycle is expired" if cycle_expires_at_lapsed?(now)
  end

  def ensure_cycle_transition_known!(current_status_id, next_status_id)
    return if self.class::TRANSITIONS.fetch(current_status_id, []).include?(next_status_id)

    raise FlowInvalidTransition, "invalid transition from #{current_status_id.inspect} to #{next_status_id.inspect}"
  end

  def ensure_cycle_not_terminal!(current_status_id)
    return unless cycle_terminal_status_ids.include?(current_status_id)

    raise FlowInvalidTransition, "terminal cycle cannot transition"
  end

  def cycle_terminal_status_ids
    %w(COMPLETED FAILED EXPIRED CANCELLED HALTED).filter_map do |name|
      cycle_status_id_for(name)
    rescue KeyError
      nil
    end
  end

  def cycle_status_id_for(status_name)
    if respond_to?(:status_id_for)
      status_id_for(status_name)
    elsif respond_to?(:state_id_for)
      state_id_for(status_name)
    else
      self.class.status_id_for(status_name)
    end
  end

  def cycle_transition_attributes(next_status_id, now, changes, timestamp_fields: [])
    attributes = changes.dup
    attributes[configured_cycle_status_column] = next_status_id

    if has_attribute?(:state)
      attributes[:state] = self.class.status_name_for(next_status_id)
    end
    if has_attribute?(:step)
      attributes[:step] = cycle_step_for_status(next_status_id)
    end
    if has_attribute?(:completed_at) && next_status_id == cycle_status_id_for("COMPLETED")
      attributes[:completed_at] = now
    end
    Array(timestamp_fields).each { |field| attributes[field] = now }
    attributes
  end

  def cycle_step_for_status(status_id)
    if self.class.const_defined?(:STEP_BY_STATUS_ID, false)
      self.class::STEP_BY_STATUS_ID.fetch(status_id)
    else
      self.class.status_name_for(status_id).downcase.delete_suffix("_pending")
    end
  end

  def ensure_cycle_column!(column)
    return if has_attribute?(column)

    raise FlowConfigurationError, "#{self.class.name} does not have #{column}"
  end

  def retainable_required!(method_name)
    return if respond_to?(method_name)

    raise FlowConfigurationError,
          "#{self.class.name} must `include Retainable` to use cycle_#{method_name.to_s.delete_suffix("?")}?"
  end

  def cycle_expires_at_lapsed?(now)
    return false unless has_attribute?(:expires_at)

    cycle_past_or_present_time?(expires_at, now)
  end

  def ensure_retention_order!(discard_at:, purge_eligible_at:)
    raise ArgumentError, "discard_at is required" if discard_at.blank?
    raise ArgumentError, "purge_eligible_at is required" if purge_eligible_at.blank?
    raise ArgumentError, "discard_at must be <= purge_eligible_at" if cycle_time_after?(discard_at, purge_eligible_at)
  end

  def cycle_past_or_present_time?(value, now)
    return false if value.blank? || cycle_infinite_time?(value)

    value <= now
  end

  def cycle_time_after?(left, right)
    return false if left.blank? || right.blank?
    return false if cycle_infinite_time?(left) && cycle_infinite_time?(right)
    return true if cycle_infinite_time?(left)
    return false if cycle_infinite_time?(right)

    left > right
  end

  def cycle_infinite_time?(value)
    value.respond_to?(:infinite?) && value.infinite?
  end
end

# rubocop:enable ThreadSafety/ClassAndModuleAttributes
