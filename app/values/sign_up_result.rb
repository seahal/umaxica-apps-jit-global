# typed: false
# frozen_string_literal: true

STATUSES = %i(
  ok
  advanced
  blocked
  invalid_transition
  unauthorized
  expired
  failed
  completed
).freeze

SUCCESS_STATUSES = %i(ok advanced completed).freeze
FAILURE_STATUSES = %i(
  blocked
  invalid_transition
  unauthorized
  expired
  failed
).freeze

SignUpResult =
  Data.define(
    :status,
    :ticket,
    :step,
    :response,
    :errors,
    :next_event,
    :cleanup_required,
    :audit_events,
  ) do
    def self.build(
      status:,
      ticket: nil,
      step: nil,
      response: nil,
      errors: [],
      next_event: nil,
      cleanup_required: false,
      audit_events: []
    )
      normalized_status = status.to_sym
      raise ArgumentError,
            "unknown sign-up result status: #{status.inspect}" unless STATUSES.include?(normalized_status)

      new(
        status: normalized_status,
        ticket: ticket,
        step: step || ticket&.step,
        response: response,
        errors: Array(errors),
        next_event: next_event,
        cleanup_required: !!cleanup_required,
        audit_events: Array(audit_events),
      )
    end

    def success?
      SUCCESS_STATUSES.include?(status)
    end

    def failure?
      FAILURE_STATUSES.include?(status)
    end

    def cleanup_required?
      cleanup_required
    end
  end
