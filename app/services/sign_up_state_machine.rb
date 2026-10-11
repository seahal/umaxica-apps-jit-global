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
    handoff_to_sign_in
    complete
    fail
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
    # Reject events on TTL-expired or logically-discarded tickets. The union
    # is intentional: discarded rows must not accept transitions any more
    # than expired ones can, but the two states are surfaced separately
    # (SignFlow#expired? = TTL only; Retainable#lapsed? = logical deletion).
    return expired_result if (ticket.expired? || ticket_lapsed?) && event != :expire

    return invalid("terminal ticket cannot transition") if terminal? && !terminal_event_allowed?

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
      transition_to!("CONTACT_PENDING", step: "contact", next_event: :verify_contact)
    when :verify_contact
      transition_to!("CONTACT_VERIFIED", step: "contact_verified", next_event: :enter_guardrail)
    when :start_social_callback
      start_social_callback
    when :complete_social_callback
      complete_social_callback
    when :enter_guardrail
      transition_to!("GUARDRAIL_PENDING", step: "guardrail", next_event: :enter_checkpoint)
    when :enter_checkpoint
      return invalid("guardrail is required") unless status?("GUARDRAIL_PENDING")

      transition_to!("CHECKPOINT_PENDING", step: "checkpoint", next_event: :clear_requirement)
    when :clear_requirement
      clear_requirement
    when :finalize
      finalize
    when :handoff_to_sign_in
      handoff_to_sign_in
    when :complete
      complete
    when :fail
      terminal_transition!("FAILED", step: "failed", timestamp: :failed_at, status: :failed, cleanup_required: true)
    when :expire
      terminal_transition!("EXPIRED", step: "expired", status: :expired, cleanup_required: true)
    when :cancel
      return invalid("ticket is not cancelable") if ticket.respond_to?(:sign_up_cancelable?) &&
        !ticket.sign_up_cancelable?

      terminal_transition!(
        "CANCELLED", step: "cancelled", timestamp: :cancelled_at, status: :failed,
                     cleanup_required: true,
      )
    end
  end

  def start_social_callback
    registry = SignUpRequirementRegistry.for_ticket(ticket)
    return invalid("social callback is app social only") unless registry.surface == :app && registry.social?

    transition_to!("SOCIAL_CALLBACK_PENDING", step: "social_callback", next_event: :complete_social_callback)
  end

  def complete_social_callback
    registry = SignUpRequirementRegistry.for_ticket(ticket)
    return invalid("social callback is app social only") unless registry.surface == :app && registry.social?

    if payload[:sign_in_handoff].present?
      SignUpResult.build(
        status: :sign_in_handoff_accepted,
        ticket: ticket,
        sign_in_handoff: payload[:sign_in_handoff],
        next_event: :handoff_to_sign_in,
      )
    else
      transition_to!("CHECKPOINT_PENDING", step: "checkpoint", next_event: :clear_requirement)
    end
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

    ticket.transition_to!("FINALIZING", step: "finalizing")
    ticket.transition_to!("FINALIZED", step: "finalized")
    SignUpResult.build(status: :advanced, ticket: ticket, next_event: :handoff_to_sign_in)
  end

  def handoff_to_sign_in
    return invalid("ticket is not finalized") unless status?("FINALIZED")

    handoff_status = payload[:sign_in_handoff_status]&.to_sym
    handoff_result = payload[:sign_in_handoff]
    return blocked("sign-in handoff result is required") if handoff_status.blank?

    case handoff_status
    when :accepted
      ticket.transition_to!("SIGN_IN_HANDOFF_PENDING", step: "sign_in_handoff")
      SignUpResult.build(
        status: :sign_in_handoff_accepted,
        ticket: ticket,
        sign_in_handoff: handoff_result,
        next_event: :complete,
      )
    when :stopped
      SignUpResult.build(status: :sign_in_handoff_stopped, ticket: ticket, sign_in_handoff: handoff_result)
    when :failed
      SignUpResult.build(status: :sign_in_handoff_failed, ticket: ticket, sign_in_handoff: handoff_result)
    else
      invalid("unknown sign-in handoff status")
    end
  end

  def complete
    ticket.complete_sign_up!
    SignUpResult.build(status: :completed, ticket: ticket)
  end

  def transition_to!(status_name, step:, next_event:)
    ticket.transition_to!(status_name, step: step)
    SignUpResult.build(status: :advanced, ticket: ticket, next_event: next_event)
  end

  def terminal_transition!(status_name, step:, status:, cleanup_required:, timestamp: nil)
    attrs = { step: step }
    attrs[timestamp] = Time.current if timestamp && ticket.has_attribute?(timestamp)
    ticket.update!(attrs)
    ticket.transition_to!(status_name, step: step)
    SignUpResult.build(status: status, ticket: ticket, cleanup_required: cleanup_required)
  end

  def status?(status_name)
    ticket.status_id == ticket.status_id_for(status_name)
  end

  def terminal?
    if ticket.respond_to?(:sign_up_terminal?)
      ticket.sign_up_terminal?
    else
      %w(COMPLETED FAILED EXPIRED CANCELLED).any? { |status_name| status?(status_name) }
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
