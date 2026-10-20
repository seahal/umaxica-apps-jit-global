# typed: false
# frozen_string_literal: true

# Unified terminal-event service for sign-up cycles. Handles the orchestration
# that the raw `SignUpStateMachine` does not own:
#
# 1. Acquire row lock on the cycle (in a transaction -- see FlowBase).
# 2. Drive the state machine to the terminal status (CANCELLED/EXPIRED/HALTED).
# 3. Schedule retention (discard now, purge after PHYSICAL_PURGE_DELAY) on the
#    cycle row via Retainable#discard_now!.
# 4. Mark `cleanup_status_id = PENDING` so the worker -- or the synchronous
#    cleanup below -- can advance it.
# 5. Outside the transaction, run SignUpArtifactCleanup synchronously to log out the
#    pending dependent records (contact, passkey, actor) before returning.
#    The worker remains the fallback for failures and out-of-band terminations.
#
# Replays on already-terminal cycles are idempotent: cleanup is re-enqueued if
# it never completed; otherwise the call is a no-op and the cycle is reloaded.
#
# Direct `SignUpStateMachine.call(event: :cancel | :expire | :halt, ...)`
# WITHOUT going through this service will skip retention scheduling and
# cleanup -- pending dependent rows will not be tidied and the cycle will
# never be physically purged. Production callers must use SignUpTermination (or one
# of its event-specific shims like SignUpCancellation).
class SignUpTermination
  PHYSICAL_PURGE_DELAY = 30.minutes

  TERMINAL_EVENTS = %i(cancel expire halt).freeze

  def self.call(...)
    new(...).call
  end
  public_class_method :call

  # Evaluate a system-only halt predicate and, when it matches, perform the halt while the
  # predicate's row lock is still held. This is intentionally narrower than `call`: callers cannot
  # supply an arbitrary transition or lifecycle status, and the predicate receives the reloaded
  # cycle that owns the lock. Cleanup remains after commit, but the decision and HALTED transition
  # are one database transaction.
  def self.halt_if_phase_violation(cycle:, &)
    new(cycle: cycle, event: :halt).halt_if_phase_violation(&)
  end
  public_class_method :halt_if_phase_violation

  def initialize(cycle:, event:, actor_context: nil)
    @cycle = cycle
    @event = event.to_sym
    @actor_context = actor_context
  end

  public

  def call
    return SignUpResult.build(status: :blocked, ticket: cycle, errors: ["ticket is required"]) unless cycle
    unless TERMINAL_EVENTS.include?(event)
      return SignUpResult.build(status: :invalid_transition, ticket: cycle, errors: ["unknown terminal event"])
    end

    if already_terminal_for_event?
      ensure_cleanup_pending! unless cleanup_completed?
      run_artifact_cleanup
      return SignUpResult.build(status: :ok, ticket: cycle.reload)
    end

    result = nil
    cycle.class.transaction do
      cycle.lock!
      result = SignUpStateMachine.call(ticket: cycle, event: event, actor_context: actor_context)
      cycle.reload
      schedule_terminal_retention! if terminal_status_reached?
    end

    return result unless terminal_status_reached?

    run_artifact_cleanup
    SignUpResult.build(status: (event == :cancel) ? :ok : result.status, ticket: cycle.reload, cleanup_required: true)
  end

  def halt_if_phase_violation
    raise ArgumentError, "phase-violation predicate required" unless block_given?
    return nil unless cycle

    decision = nil
    cycle.with_cycle_lock do
      cycle.reload
      decision = yield(cycle)
      next unless decision.is_a?(Hash) && decision[:halt]

      SignUpStateMachine.call(ticket: cycle, event: :halt, actor_context: nil)
      cycle.reload
      schedule_terminal_retention! if terminal_status_reached?
      decision = decision.merge(
        halted: cycle.respond_to?(:sign_up_halted?) && cycle.sign_up_halted?,
        subject: sign_up_principal,
      )
    end

    return decision unless decision.is_a?(Hash) && decision[:halted]

    run_artifact_cleanup
    decision
  end

  private

  attr_reader :cycle, :event, :actor_context

  def sign_up_principal
    return if cycle.principal_id.blank?

    case cycle
    when ClientSignUpFlow, VisitorSignUpFlow
      cycle.association(:principal).tap { |owner| owner.reset_scope }.scope.take!
    else raise ArgumentError, "unsupported sign-up cycle realm"
    end
  end

  def already_terminal_for_event?
    case event
    when :cancel then cycle.respond_to?(:sign_up_cancelled?) && cycle.sign_up_cancelled?
    when :expire then cycle_status_name == "EXPIRED"
    when :halt   then cycle_status_name == "HALTED"
    end
  end

  def terminal_status_reached?
    case event
    when :cancel then cycle.respond_to?(:sign_up_cancelled?) && cycle.sign_up_cancelled?
    when :expire then cycle_status_name == "EXPIRED"
    when :halt   then cycle_status_name == "HALTED"
    end
  end

  def cycle_status_name
    cycle.class::STATUS_NAMES[cycle.status_id]
  rescue StandardError
    nil
  end

  def cleanup_completed?
    cleanup_supported? && cycle.cleanup_completed?
  end

  def ensure_cleanup_pending!
    return unless cleanup_supported?
    return if cycle.cleanup_pending?

    cycle.with_cycle_lock do
      cycle.reload
      next if cycle.cleanup_completed?

      cycle.update!(cleanup_status_id: cycle.cleanup_status_id_for(:pending), cleanup_error_code: nil)
    end
  end

  def schedule_terminal_retention!
    cycle.discard_now!(purge_after: PHYSICAL_PURGE_DELAY) if cycle.respond_to?(:discard_now!)
    return unless cleanup_supported?

    attrs = { cleanup_status_id: cycle.cleanup_status_id_for(:pending) }
    attrs[:cleanup_error_code] = nil if cycle.has_attribute?(:cleanup_error_code)
    attrs[:cleanup_attempted_at] = nil if cycle.has_attribute?(:cleanup_attempted_at)
    attrs[:cleanup_completed_at] = nil if cycle.has_attribute?(:cleanup_completed_at)
    cycle.update!(attrs)
  end

  def run_artifact_cleanup
    if cycle.is_a?(ClientSignUpFlow) && ClientSecretIssuance.exists?(sign_up_flow_ref: cycle.public_id)
      ClientSecretPasskeyReservationIssuer.terminate_sign_up!(
        flow: cycle, purge_after: ClientSecretLifetimesValue.purge_delay,
      )
    end
    return unless cleanup_supported?
    return if cycle.cleanup_completed?

    SignUpArtifactCleanup.call(cycle: cycle)
  end

  def cleanup_supported?
    cycle.respond_to?(:cleanup_pending?) && cycle.has_attribute?(:cleanup_status_id)
  end
end
