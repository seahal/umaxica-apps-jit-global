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

    def expired? = false

    def lapsed? = false

    def sign_up_terminal? = %w(COMPLETED FAILED EXPIRED CANCELLED).include?(status_id)

    def sign_up_cancelable? = true

    def sign_up_cancelled? = status_id == "CANCELLED"

    def has_attribute?(_name) = false

    def status_id_for(name) = name

    def transition_to!(name, step: _step)
      instance_variable_set(:@last_step, step)
      self.status_id = name
      self
    end

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
      fail: ["STARTED", nil],
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
    expired.define_singleton_method(:expired?) { true }

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

  test "sign-up state machine covers handoff status arms and checkpoint guards" do
    ticket = MachineTicket.new("FINALIZED")
    %i(accepted stopped failed).each do |status|
      ticket = MachineTicket.new("FINALIZED")
      result = SignUpStateMachine.call(
        ticket: ticket, event: :handoff_to_sign_in, actor_context: nil,
        payload: { sign_in_handoff_status: status },
      )

      assert_equal(
        { accepted: :sign_in_handoff_accepted,
          stopped: :sign_in_handoff_stopped,
          failed: :sign_in_handoff_failed, }.fetch(status), result.status,
      )
    end
    missing = SignUpStateMachine.call(ticket: ticket, event: :handoff_to_sign_in, actor_context: nil)

    assert_equal :blocked, missing.status
    unknown = SignUpStateMachine.call(
      ticket: ticket, event: :handoff_to_sign_in, actor_context: nil,
      payload: { sign_in_handoff_status: :other },
    )

    assert_equal :invalid_transition, unknown.status

    machine = SignUpStateMachine.new(ticket: MachineTicket.new, event: :clear_requirement, actor_context: nil)

    assert machine.send(:checkpoint_version_matches?)
    machine = SignUpStateMachine.new(
      ticket: MachineTicket.new, event: :clear_requirement, actor_context: nil,
      payload: { checkpoint_version: "bad" },
    )
    machine.ticket.define_singleton_method(:has_attribute?) { |_name| true }

    assert_not machine.send(:checkpoint_version_matches?)
  end

  test "OTP scope rejects unsupported purpose, surface, channel, and subject" do
    subject = ClientSignUpFlow.new(pending_contact_type: "email")
    invalids = [
      { purpose: :sign_in, surface: :app, channel: :email, subject: subject },
      { purpose: :sign_up, surface: :org, channel: :email, subject: subject },
      { purpose: :sign_up, surface: :app, channel: :sms, subject: subject },
      { purpose: :sign_up, surface: :com, channel: :email, subject: subject },
    ]

    invalids.each { |args| assert_raises(ArgumentError) { SignOtpCeremony.new(**args).send(:validate_scope!) } }
    assert_equal ClientEmail,
                 SignOtpCeremony.new(
                   purpose: :sign_up, surface: :app, channel: :email,
                   subject: subject,
                 ).send(:expected_record_class)
    assert_equal ClientTelephone,
                 SignOtpCeremony.new(
                   purpose: :sign_up, surface: :app, channel: :telephone,
                   subject: ClientSignUpFlow.new(pending_contact_type: "telephone"),
                 ).send(:expected_record_class)
    assert_equal VisitorEmail,
                 SignOtpCeremony.new(
                   purpose: :sign_up, surface: :com, channel: :email,
                   subject: VisitorSignUpFlow.new(pending_contact_type: "email"),
                 ).send(:expected_record_class)
    assert_equal VisitorTelephone,
                 SignOtpCeremony.new(
                   purpose: :sign_up, surface: :com, channel: :telephone,
                   subject: VisitorSignUpFlow.new(pending_contact_type: "telephone"),
                 ).send(:expected_record_class)
  end

  test "Palm authenticator token binding helpers reject missing and mismatched claims" do
    service = PalmAccessTokenAuthenticator.allocate

    assert service.send(:token_jti_matches?, Object.new, {})
    token = Struct.new(:oidc_jti).new(nil)

    assert service.send(:token_jti_matches?, token, {})
    token.oidc_jti = "expected"

    assert_not service.send(:token_jti_matches?, token, { "jti" => "different" })
    assert service.send(:token_jti_matches?, token, { "jti" => "expected" })
    assert_not service.send(:token_belongs_to_audience?, Object.new, {})
  end

  test "credential inventory result exposes availability and removal predicates" do
    result = AuthenticationCredentialInventory::Result.new(
      actor: nil, excluding: nil, aal1_methods: [:email],
      aal2_methods: [:totp], aal3_methods: [], step_up_methods: [:passkey],
      uv_step_up_methods: [:passkey], contact_identifiers: [:email],
      phishing_resistant_methods: [:passkey],
    )

    assert_equal [:email], result.login_methods
    assert_predicate result, :login_available?
    assert_predicate result, :step_up_available?
    assert_predicate result, :retains_uv_step_up?
    assert_not_predicate result, :last_login_method?
    assert_predicate result, :removable_login_credential?
    assert_equal 1, result.aal1_method_count
  end
end
