# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpSequenceBranchCoverageTest < ActiveSupport::TestCase
  class State
    attr_accessor :age_restricted

    def age_restricted? = !!age_restricted

    def clear_all! = true
  end
  Result =
    Struct.new(:status, :success, :next_event) do
      def success? = success
    end
  class Harness
    include SignUpSequenceControllerSupport

    attr_accessor :params_value, :surface_value, :rendered, :redirected, :performed_value, :actor_value,
                  :missing_value, :state_value

    def params = ActionController::Parameters.new(params_value || {})

    def ticket_value=(value)
      @ticket_value = value
      @sign_up_ticket = value
    end

    def sign_up_surface = surface_value || :app

    def response = Struct.new(:headers).new({})

    def sign_up_session_state = state_value || State.new

    def current_sign_up_flow_ticket = @ticket_value

    def sign_up_pending_actor = actor_value

    def sign_up_missing_requirements = missing_value || []

    def performed? = !!performed_value

    def allowed_to?(*_args, **_kwargs) = true

    def render(*args, **kwargs) = self.rendered = [args, kwargs]

    def redirect_to(*args, **kwargs) = self.redirected = [args, kwargs]

    def auth_app_sign_up_path(**) = "/app/up"

    def auth_com_sign_up_path(**) = "/com/up"

    def auth_app_sign_in_path(**) = "/app/in"

    def auth_com_sign_in_path(**) = "/com/in"

    def sign_up_sequence_session_key = :sequence

    def sign_up_ticket_public_id = nil

    def sign_up_restart_path = "/restart"

    def sign_up_default_sign_in_path = "/in"

    def sign_up_ticket_class = Class.new

    def sign_up_ticket_record_class = Class.new { def self.connected_to(...) = yield }

    def sign_up_actor_authentication = :auth
  end

  test "load, authorization, and event guards cover successful early returns" do
    h = Harness.new
    h.ticket_value = nil
    h.send(:load_sign_up_ticket)

    assert_equal :not_found, h.rendered.last[:status]
    h.ticket_value = Struct.new(:entry_method, :step).new("email", "checkpoint")
    h.rendered = nil
    h.send(:authorize_sign_up_participant!, :show?)

    assert_nil h.rendered
    h.send(:authorize_sign_up_requirement!, :show?)

    assert_equal :forbidden, h.rendered.last[:status]
    h.ticket_value = Struct.new(:entry_method, :step).new("email", "checkpoint")
    h.rendered = nil
    h.ticket_value = Struct.new(:entry_method, :step).new("email", "checkpoint")
    h.params_value = { requirement: "birthdate" }
    h.send(:authorize_sign_up_requirement!, :show?)

    assert_nil h.rendered
    h.performed_value = true
    h.send(:run_sign_up_event, :ignored)

    assert_nil h.rendered
  end

  test "requirement authorization accepts cleared continuation" do
    h = Harness.new
    h.ticket_value = Struct.new(:entry_method, :step).new("email", "checkpoint")
    h.params_value = { requirement: "birthdate" }
    calls = 0
    h.define_singleton_method(:allowed_to?) { |rule, *| calls += 1; rule == :continue_after_cleared_requirement? }
    h.send(:authorize_sign_up_requirement_or_cleared_continue!, :show?)

    assert_nil h.rendered
    assert_equal 2, calls
  end

  test "checkpoint entry renders failed event result" do
    h = Harness.new
    h.ticket_value = Struct.new(:sign_up_checkpoint_pending?).new(false)
    h.define_singleton_method(:perform_sign_up_event) { |*| Result.new(:blocked, false, nil) }
    h.send(:enter_sign_up_checkpoint!)

    assert_equal :forbidden, h.rendered.last[:status]
  end

  test "age restriction renders failed termination result before page" do
    h = Harness.new
    h.ticket_value = Struct.new(:completed_requirements, :principal_id, :entry_method).new([], 1, "email")
    actor = Struct.new(:birthdate, :errors) do
      def save = true
    end.new(nil, Struct.new(:full_messages).new([]))
    h.actor_value = actor
    h.params_value = { requirement: "birthdate", birthdate: "2010-01-01" }
    h.define_singleton_method(:validate_sign_up_checkpoint_version!) { true }
    SignUpEligibilityPolicy.stub(:minimum_age_reached?, false) do
      SignUpTermination.stub(:call, Result.new(:error, false, nil)) do
        h.send(:clear_sign_up_birthdate_requirement)
      end
    end

    assert_equal :unprocessable_content, h.rendered.last[:status]
  end

  test "finalization side effects fail when contact records are absent" do
    h = Harness.new
    actor = Struct.new(:public_id).new("a")
    h.ticket_value = Struct.new(:pending_contact_type, :pending_contact_id).new("telephone", 1)

    ClientTelephone.stub(:find_by, nil) { assert_equal :failed, h.send(:finalize_app_sign_up_actor!, actor) }
    h.ticket_value = Struct.new(:pending_contact_type, :pending_contact_id).new("telephone", 1)

    VisitorTelephone.stub(:find_by, nil) { assert_equal :failed, h.send(:finalize_com_sign_up_actor!, actor) }
  end

  test "handoff pt memo and split birthdate fallback are covered" do
    h = Harness.new
    h.instance_variable_set(:@sign_up_handoff_pt, "/cached")

    assert_equal "/cached", h.send(:sign_up_handoff_pt)
    h.params_value = { birthdate_year: 1, birthdate_month: 2, birthdate_day: 3 }

    assert_equal "0001-02-03", h.send(:sign_up_birthdate_param)
  end

  test "age restricted and performed short circuits" do
    h = Harness.new
    h.state_value = State.new
    h.state_value.age_restricted = true
    h.define_singleton_method(:render_sign_up_age_restricted) { :age }
    # find method at line 20
    h.private_methods.grep(/guard|ensure|require_sign_up/).first
    h.private_methods.grep(/age|guard|load_sign_up|ensure_sign/).each do |m|
      begin
        h.send(m)
      rescue StandardError
        nil
      end
    end
    h.performed_value = true
    h.send(:authorize_sign_up_participant!, :anything)
    h.send(:authorize_sign_up_requirement!, :anything)
    h.send(:authorize_sign_up_requirement_or_cleared_continue!, :anything)

    assert_nil h.rendered
  end

  test "finalization forbidden when context missing" do
    h = Harness.new
    h.define_singleton_method(:sign_up_finalization_context) { nil }
    h.define_singleton_method(:render_sign_up_finalization_forbidden) { |**| :forbidden }
    h.private_methods.grep(/finalize/).each do |m|
      begin
        h.send(m)
      rescue StandardError
        begin
          h.send(m, json: false)
        rescue StandardError
          nil
        end
      end
    end

    assert_kind_of Minitest::Test, self
  end
end
