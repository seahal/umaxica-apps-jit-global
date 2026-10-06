# typed: false
# frozen_string_literal: true

class SignUpStateMachine
  EVENTS = %i(
    start
    submit_contact
    verify_contact
    start_social_callback
    complete_social_callback
    enter_guardrail
    enter_checkpoint
    clear_requirement
    finalize
    complete
    halt
    expire
    cancel
  ).freeze

  def self.call(ticket:, event:, actor_context:, payload: {})
    normalized_event = event.to_sym
    unless EVENTS.include?(normalized_event)
      return SignUpResult.build(status: :invalid_transition, ticket: ticket, errors: ["unknown event"])
    end

    new(ticket: ticket, event: normalized_event, actor_context: actor_context, payload: payload).call
  end

  attr_reader :ticket, :event, :actor_context, :payload

  def initialize(ticket:, event:, actor_context:, payload: {})
    @ticket = ticket
    @event = event
    @actor_context = actor_context
    @payload = payload.respond_to?(:to_h) ? payload.to_h : {}
  end

  def call
    return invalid("ticket is required") unless ticket

    # Serialize the state-machine evaluation under the same row-level lock
    # the transitions themselves use. Without this, callers can read a
    # stale `status_id` between policy check and `transition_to!`, leading
    # to two writers both attempting the same outbound transition. The
    # transition itself would still raise `InvalidTransition` for the
    # loser, but only AFTER any side effects the caller already performed
    # (e.g. actor mutations in finalize). Locking here serializes the
    # *decision*, not just the write.
    if ticket.persisted? && ticket.respond_to?(:with_cycle_lock)
      evaluate_under_lock
    else
      evaluate_event
    end
  rescue ArgumentError, ActiveRecord::RecordInvalid, FlowInvalidTransition => e
    invalid(e.message)
  end

  private

  def evaluate_under_lock
    result = nil
    ticket.with_cycle_lock do
      ticket.reload
      result = evaluate_event
    end
    result
  end

  def evaluate_event
    return ok if event == :cancel && ticket.respond_to?(:sign_up_cancelled?) && ticket.sign_up_cancelled?
    return invalid("terminal ticket cannot transition") if terminal? && !terminal_event_allowed?

    # An expired non-terminal row is durably terminalized before the caller
    # receives the refusal. Logical discard remains a separate retention
    # condition and is rejected without changing lifecycle state.
    if event != :expire && ticket.expired?(ticket.class.database_now)
      ticket.expire_sign_up!
      return expired_result
    end
    return expired_result if ticket_lapsed? && event != :expire

    dispatch_event
  end

  def ticket_lapsed?
    ticket.respond_to?(:lapsed?) && ticket.lapsed?
  end

  def dispatch_event
    case event
    when :start
      ok(next_event: :submit_contact)
    when :submit_contact
      ticket.advance_sign_up_to_contact!
      SignUpResult.build(status: :advanced, ticket: ticket, next_event: :verify_contact)
    when :verify_contact
      ticket.verify_sign_up_contact!
      SignUpResult.build(status: :advanced, ticket: ticket, next_event: :enter_guardrail)
    when :start_social_callback
      start_social_callback
    when :complete_social_callback
      complete_social_callback
    when :enter_guardrail
      ticket.advance_sign_up_to_guardrail!
      SignUpResult.build(status: :advanced, ticket: ticket, next_event: :enter_checkpoint)
    when :enter_checkpoint
      return invalid("guardrail is required") unless status?("GUARDRAIL_PENDING")

      ticket.advance_sign_up_to_checkpoint!
      SignUpResult.build(status: :advanced, ticket: ticket, next_event: :clear_requirement)
    when :clear_requirement
      clear_requirement
    when :finalize
      finalize
    when :complete
      complete
    when :halt
      ticket.halt_sign_up!
      SignUpResult.build(status: :failed, ticket: ticket, cleanup_required: true)
    when :expire
      ticket.expire_sign_up!
      SignUpResult.build(status: :expired, ticket: ticket, cleanup_required: true)
    when :cancel
      return invalid("ticket is not cancelable") if ticket.respond_to?(:sign_up_cancelable?) &&
        !ticket.sign_up_cancelable?

      ticket.cancel_sign_up!
      SignUpResult.build(status: :failed, ticket: ticket, cleanup_required: true)
    end
  end

  def start_social_callback
    registry = SignUpRequirementRegistry.for_ticket(ticket)
    return invalid("social callback is app social only") unless registry.surface == :app && registry.social?

    ticket.start_sign_up_social_callback!
    SignUpResult.build(status: :advanced, ticket: ticket, next_event: :complete_social_callback)
  end

  def complete_social_callback
    registry = SignUpRequirementRegistry.for_ticket(ticket)
    return invalid("social callback is app social only") unless registry.surface == :app && registry.social?

    ticket.advance_sign_up_to_checkpoint!
    SignUpResult.build(status: :advanced, ticket: ticket, next_event: :clear_requirement)
  end

  def clear_requirement
    return invalid("ticket is not at checkpoint") unless status?("CHECKPOINT_PENDING")

    return invalid("checkpoint is stale") unless checkpoint_version_matches?

    requirement = payload[:requirement]&.to_sym
    registry = SignUpRequirementRegistry.for_ticket(ticket)
    return invalid("requirement is required") if requirement.blank?
    return invalid("requirement does not belong to entry method") unless registry.requirement?(requirement)
    return invalid("prior requirement is not clear") unless
      registry.prior_requirements_cleared?(ticket.completed_requirements, requirement)
    return invalid("requirement is already clear") if
      registry.requirement_cleared?(ticket.completed_requirements, requirement)

    before_clear = payload[:before_clear]
    before_clear.call if before_clear.respond_to?(:call)

    requirements = ticket.completed_requirements.deep_dup
    requirements[requirement.to_s] = {
      "cleared" => true,
      "cleared_at" => Time.current.iso8601,
    }
    attrs = { completed_requirements: requirements }
    attrs[:checkpoint_version] = ticket.checkpoint_version + 1 if ticket.has_attribute?(:checkpoint_version)
    ticket.update!(attrs)

    missing = registry.missing_requirements(ticket.completed_requirements)
    SignUpResult.build(
      status: :advanced,
      ticket: ticket,
      next_event: missing.empty? ? :finalize : :clear_requirement,
    )
  end

  def finalize
    return invalid("ticket is not at checkpoint") unless status?("CHECKPOINT_PENDING")

    registry = SignUpRequirementRegistry.for_ticket(ticket)
    missing = registry.missing_requirements(ticket.completed_requirements)
    return blocked("missing requirements: #{missing.join(", ")}") if missing.any?
    return blocked("finalization result is required") if payload[:finalization_result].blank?
    return failed(
      "finalization failed",
      cleanup_required: true,
    ) unless payload[:finalization_result].to_sym == :accepted

    ticket.begin_sign_up_finalization!
    SignUpResult.build(status: :advanced, ticket: ticket, next_event: :complete)
  end

  def complete
    ticket.complete_sign_up!
    SignUpResult.build(status: :completed, ticket: ticket)
  end

  def status?(status_name)
    ticket.status_id == ticket.status_id_for(status_name)
  end

  def terminal?
    if ticket.respond_to?(:sign_up_terminal?)
      ticket.sign_up_terminal?
    else
      %w(COMPLETED FAILED EXPIRED CANCELLED HALTED).any? { |status_name| status?(status_name) }
    end
  end

  def terminal_event_allowed?
    event == :start || (event == :cancel && ticket.respond_to?(:sign_up_cancelled?) && ticket.sign_up_cancelled?)
  end

  def checkpoint_version_matches?
    return true unless ticket.has_attribute?(:checkpoint_version)

    submitted_version = payload[:checkpoint_version]
    return false if submitted_version.blank?

    Integer(submitted_version.to_s, 10) == ticket.checkpoint_version
  rescue ArgumentError, TypeError
    false
  end

  def ok(next_event: nil)
    SignUpResult.build(status: :ok, ticket: ticket, next_event: next_event)
  end

  def blocked(message)
    SignUpResult.build(status: :blocked, ticket: ticket, errors: [message])
  end

  def failed(message, cleanup_required: false)
    SignUpResult.build(status: :failed, ticket: ticket, errors: [message], cleanup_required: cleanup_required)
  end

  def invalid(message)
    SignUpResult.build(status: :invalid_transition, ticket: ticket, errors: [message])
  end

  def expired_result
    SignUpResult.build(status: :expired, ticket: ticket, errors: ["ticket is expired"])
  end
end
