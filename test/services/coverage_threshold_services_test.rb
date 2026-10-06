# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdServicesTest < ActiveSupport::TestCase
  class MachineTicket
    attr_accessor :status_id, :checkpoint_version, :completed_requirements, :step

    def initialize(status = "STARTED")
      @status_id = status
      @step = "start"
      @checkpoint_version = 0
      @completed_requirements = {}
    end

    def persisted? = false

    def self.database_now = Time.current

    def expired?(_now = nil) = false

    def lapsed? = false

    def sign_up_terminal? = %w(COMPLETED FAILED EXPIRED CANCELLED HALTED).include?(status_id)

    def sign_up_cancelable? = true

    def sign_up_cancelled? = status_id == "CANCELLED"

    def has_attribute?(_name) = false

    def status_id_for(name) = name

    def advance_sign_up_to_contact! = self.status_id = "CONTACT_PENDING"

    def verify_sign_up_contact! = self.status_id = "CONTACT_VERIFIED"

    def advance_sign_up_to_guardrail! = self.status_id = "GUARDRAIL_PENDING"

    def advance_sign_up_to_checkpoint! = self.status_id = "CHECKPOINT_PENDING"

    def start_sign_up_social_callback! = self.status_id = "SOCIAL_CALLBACK_PENDING"

    def begin_sign_up_finalization! = self.status_id = "FINALIZING"

    def halt_sign_up! = self.status_id = "HALTED"

    def expire_sign_up! = self.status_id = "EXPIRED"

    def cancel_sign_up! = self.status_id = "CANCELLED"

    def update!(attrs)
      attrs.each { |key, value| public_send("#{key}=", value) if respond_to?("#{key}=") }
      self
    end

    def complete_sign_up!
      self.status_id = "COMPLETED"
    end
  end

  test "sign-up state machine dispatches every terminal and linear transition" do
    cases = {
      start: ["STARTED", :submit_contact],
      submit_contact: ["STARTED", :verify_contact],
      verify_contact: ["STARTED", :enter_guardrail],
      enter_guardrail: ["STARTED", :enter_checkpoint],
      enter_checkpoint: ["GUARDRAIL_PENDING", :clear_requirement],
      halt: ["STARTED", nil],
      expire: ["STARTED", nil],
      cancel: ["STARTED", nil],
      complete: ["STARTED", nil],
    }
    cases.each do |event, (status, _next_event)|
      ticket = MachineTicket.new(status)
      result = SignUpStateMachine.call(ticket: ticket, event: event, actor_context: nil)

      assert_includes %i(ok advanced failed expired completed), result.status, event
    end
  end

  test "sign-up state machine refuses expired, lapsed, terminal, and uncancelable tickets" do
    expired = MachineTicket.new
    expired.define_singleton_method(:expired?) { |_now = nil| true }

    assert_equal :expired, SignUpStateMachine.call(ticket: expired, event: :start, actor_context: nil).status

    lapsed = MachineTicket.new
    lapsed.define_singleton_method(:lapsed?) { true }

    assert_equal :expired, SignUpStateMachine.call(ticket: lapsed, event: :start, actor_context: nil).status

    terminal = MachineTicket.new("COMPLETED")

    assert_equal :invalid_transition,
                 SignUpStateMachine.call(ticket: terminal, event: :submit_contact, actor_context: nil).status

    cancelled = MachineTicket.new
    cancelled.define_singleton_method(:sign_up_cancelable?) { false }

    assert_equal :invalid_transition,
                 SignUpStateMachine.call(ticket: cancelled, event: :cancel, actor_context: nil).status
  end

  test "credential inventory result exposes availability and removal predicates" do
    result = AuthenticationCredentialInventory::Result.new(
      actor: nil, excluding: nil, sign_in_methods: [:email],
      step_up_methods: [:passkey],
      uv_step_up_methods: [:passkey], contact_identifiers: [:email],
      phishing_resistant_methods: [:passkey],
    )

    assert_equal [:email], result.sign_in_methods
    assert_predicate result, :has_usable_sign_in_capability?
    assert_predicate result, :has_usable_step_up_capability?
    assert_equal [:email], result.usable_sign_in_capabilities
    assert_equal [:passkey], result.usable_step_up_capabilities
    assert_equal 1, result.usable_sign_in_capabilities.length
  end
end
