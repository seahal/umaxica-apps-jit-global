# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthenticationSequenceGateExtraCoverageTest < ActiveSupport::TestCase
  class Result < Struct.new(:blocking)
    def blocking?
      blocking
    end
  end

  class FakeCycle
    attr_accessor :return_to, :public_id, :states, :last_update_changes

    def initialize(return_to: "/return", public_id: "seq-1", states: {})
      @return_to = return_to
      @public_id = public_id
      @states = states
    end

    def sign_in_session_limit_pending? = states[:session_limit]

    def sign_in_checkpoint_pending? = states[:checkpoint]

    def sign_in_selector_pending? = states[:selector]

    def sign_in_completed? = states[:completed]

    def sign_in_guardrail_pending? = states[:guardrail]

    def sign_in_dashboard_pending? = states[:dashboard]

    def sign_in_return_pending? = states[:return_pending]

    def reload = self

    def has_attribute?(name)
      name == :token_id
    end

    def token_id
      states[:token_id]
    end

    def update!(changes)
      self.last_update_changes = changes
      true
    end

    def status_id_for(_value)
      "dashboard-pending"
    end
  end

  class GuardrailParticipant
    def initialize(result)
      @result = result
    end

    def advance_if_clear!
      @result
    end

    def advance!
      @result
    end
  end

  class CheckpointParticipant
    def initialize(result)
      @result = result
    end

    def advance_if_clear!
      @result
    end
  end

  class Harness
    include AuthenticationSequenceGate

    attr_accessor :session_hash, :params_hash, :request_obj, :rendered, :redirected, :current_resource,
                  :cycle, :guardrail_result, :checkpoint_result, :allowed_policy, :current_session_value,
                  :selector_result

    def initialize
      @session_hash = {}
      @params_hash = { ri: "jp" }
      @request_obj = Struct.new(:path, :format).new("/selector", Struct.new(:html?).new(true))
      @cycle = nil
      @guardrail_result = Result.new(false)
      @checkpoint_result = Result.new(false)
      @selector_result = { status: :success }
    end

    def session = @session_hash

    def params = @params_hash.with_indifferent_access

    def request = @request_obj

    def logged_in? = current_resource.present?

    def current_authentication_event_at = nil

    def current_session
      @current_session_value
    end

    def current_session=(value)
      @current_session_value = value
    end

    def after_dashboard_path = "/dashboard"

    def after_welcome_path = "/welcome"

    def after_login_allows_other_host? = false

    def redirect_to(path, **kwargs) = @redirected = [path, kwargs]

    def redirect_to_jump_url(url, **kwargs) = @redirected = ["jump:#{url}", kwargs]

    def render(**kwargs) = @rendered = kwargs

    def sign_in_sequence_surface = :app

    def current_region_identifier
      RequestContextContract.normalize_region(params[:ri])
    end

    def signed_pt_token(value) = value ? "pt:#{value}" : nil

    def path_from_signed_pt(value) = value&.sub(/\Apt:/, "")

    def clear_welcome_gate! = session.delete(welcome_gate_key)

    def clear_current_sign_in_flow_locator! = (@locator_cleared = true)

    def allow_to?(rule, *_args)
      return @allowed_policy.fetch(rule) if @allowed_policy.is_a?(Hash)
      return @allowed_policy unless @allowed_policy.nil?

      true
    end

    alias allowed_to? allow_to?

    def current_db_sign_in_flow_for_sequence = @cycle

    def sign_in_sequence_carrier
      @sign_in_sequence_carrier ||= Struct.new(:current) do
        def start!(**kwargs)
          self.current = Struct.new(:id).new(kwargs[:state] || "seq-1")
          current
        end
      end.new(nil)
    end

    def with_sign_in_flow_writing(_cycle)
      yield
    end

    def sign_in_guardrail_participant(_cycle) = GuardrailParticipant.new(@guardrail_result)

    def sign_in_checkpoint_participant(_cycle) = CheckpointParticipant.new(@checkpoint_result)

    def sign_in_dashboard_participant(_cycle) = GuardrailParticipant.new(@guardrail_result)

    def sign_in_flow_actor(_cycle) = current_resource

    def issue_active_session_for_selector!(_cycle) = @selector_result

    def reset_current_db_sign_in_flow_for_sequence! = (@cycle = nil)

    def sign_in_flow_locator_for(*)
      Struct.new(:issued, :cleared) do
        def issue!(_cycle) = self.issued = true

        def clear! = self.cleared = true
      end.new(false, false)
    end

    def sign_in_selector_path(pt: nil) = super

    def sign_in_session_limit_path(pt: nil) = super

    def sign_in_checkpoint_path(pt: nil) = "/checkpoint?pt=#{pt}"

    def sign_in_welcome_path(pt: nil) = "/welcome?pt=#{pt}"

    def sign_app_sign_in_session_path(**attrs) = "/app/session?#{attrs.compact.to_query}"

    def sign_app_selector_path(**attrs) = "/app/selector?#{attrs.compact.to_query}"

    def sign_in_sequence_required_for_participant?(_participant) = true

    def bulletin_state = session[:sign_in_checkpoint]

    def controller_path = "sign/app/checkpoints"

    def log_in(*)
      { status: :success }
    end
  end

  class ExternalDashboardHarness < Harness
    def after_dashboard_path = "https://www.umaxica.app/?ri=jp"
  end

  class FallbackHarness < Harness
    undef_method :sign_app_sign_in_session_path
    undef_method :sign_app_selector_path
  end

  class OrgHarness < Harness
    undef_method :sign_app_sign_in_session_path
    undef_method :sign_app_selector_path

    def sign_org_sign_in_session_path(**attrs) = "/org/session?#{attrs.compact.to_query}"

    def sign_org_selector_path(**attrs) = "/org/selector?#{attrs.compact.to_query}"
  end

  class ComHarness < Harness
    undef_method :sign_app_sign_in_session_path
    undef_method :sign_app_selector_path

    def sign_com_sign_in_session_path(**attrs) = "/com/session?#{attrs.compact.to_query}"

    def sign_com_selector_path(**attrs) = "/com/selector?#{attrs.compact.to_query}"
  end

  class LocatorHarness < Harness
    attr_accessor :surface

    def sign_in_sequence_surface = surface

    def current_db_sign_in_flow_for_sequence
      AuthenticationSequenceGate.instance_method(:current_db_sign_in_flow_for_sequence).bind(self).call
    end
  end

  class NoCurrentSessionHarness < Harness
    undef_method :current_session

    def current_db_sign_in_flow_for_sequence
      AuthenticationSequenceGate.instance_method(:current_db_sign_in_flow_for_sequence).bind(self).call
    end
  end

  setup do
    @harness = Harness.new
  end

  test "sign_in_session_limit_path prefers surface helper and falls back to generic path" do
    assert_equal "/app/session?pt=pt%3Atarget&ri=jp", @harness.sign_in_session_limit_path(pt: "target")

    fallback = FallbackHarness.new

    assert_equal "/in/session?pt=pt%3Atarget&ri=jp", fallback.sign_in_session_limit_path(pt: "target")

    assert_equal "/org/session?pt=pt%3Atarget&ri=jp", OrgHarness.new.sign_in_session_limit_path(pt: "target")
    assert_equal "/com/session?pt=pt%3Atarget&ri=jp", ComHarness.new.sign_in_session_limit_path(pt: "target")
  end

  test "legacy bulletin session state does not hold an otherwise clear checkpoint" do
    @harness.cycle = FakeCycle.new(states: { checkpoint: true })
    @harness.session[:sign_in_checkpoint] = { "kind" => "checkpoint", "state" => "new" }

    @harness.continue_checkpoint_sequence_without_content!

    assert_equal ["/welcome?pt=/return", { allow_other_host: false }], @harness.redirected
  end

  test "sign_in_selector_path falls back to the generic selector path" do
    fallback = FallbackHarness.new

    assert_equal "/selector?pt=pt%3Atarget&ri=jp", fallback.sign_in_selector_path(pt: "target")

    assert_equal "/org/selector?pt=pt%3Atarget&ri=jp", OrgHarness.new.sign_in_selector_path(pt: "target")
    assert_equal "/com/selector?pt=pt%3Atarget&ri=jp", ComHarness.new.sign_in_selector_path(pt: "target")
  end

  test "sign-in helper paths canonicalize invalid region input" do
    harness = FallbackHarness.new
    harness.params_hash = { ri: "https://evil.example" }

    assert_equal "/in/session?pt=pt%3Atarget&ri=jp", harness.sign_in_session_limit_path(pt: "target")
    assert_equal "/selector?pt=pt%3Atarget&ri=jp", harness.sign_in_selector_path(pt: "target")
  end

  test "redirect_to_sign_in_sequence! uses jump gateway for absolute destinations" do
    harness = ExternalDashboardHarness.new
    harness.define_singleton_method(:sign_in_sequence_redirect_path) do |pt: nil, default_path: after_dashboard_path|
      _ = pt
      _ = default_path
      "https://www.umaxica.app/?ri=jp"
    end

    harness.redirect_to_sign_in_sequence!

    assert_equal ["jump:https://www.umaxica.app/?ri=jp", {}], harness.redirected
  end

  test "redirect_to_sign_in_sequence! keeps internal paths local" do
    @harness.define_singleton_method(:sign_in_sequence_redirect_path) do |pt: nil, default_path: after_dashboard_path|
      _ = pt
      _ = default_path
      "/app/session?pt=pt%3Atarget&ri=jp"
    end

    @harness.redirect_to_sign_in_sequence!(pt: "target")

    assert_equal ["/app/session?pt=pt%3Atarget&ri=jp", { allow_other_host: false }], @harness.redirected
  end

  test "redirect_after_checkpoint_sequence! never permits an external host" do
    @harness.define_singleton_method(:dashboard_sequence_step_required?) { false }

    @harness.redirect_after_checkpoint_sequence!(
      default_path: "https://evil.example/dashboard",
      allow_other_host: true,
      status: :see_other,
    )

    assert_equal [
      "https://evil.example/dashboard",
      { allow_other_host: false, status: :see_other },
    ], @harness.redirected
  end

  test "redirect_after_checkpoint_sequence! rejects, blocks, or advances a pending checkpoint cycle" do
    @harness.cycle = FakeCycle.new(states: { checkpoint: false })

    @harness.redirect_after_checkpoint_sequence!

    assert_equal :bad_request, @harness.rendered[:status]

    @harness.cycle = FakeCycle.new(states: { checkpoint: true }, return_to: "/after")
    @harness.allowed_policy = false

    @harness.redirect_after_checkpoint_sequence!

    assert_equal :bad_request, @harness.rendered[:status]

    @harness.cycle = FakeCycle.new(states: { checkpoint: true }, return_to: "/after")
    @harness.allowed_policy = true
    @harness.checkpoint_result = Result.new(true)

    @harness.redirect_after_checkpoint_sequence!(pt: "fallback")

    assert_equal ["/checkpoint?pt=/after", { allow_other_host: false }], @harness.redirected

    @harness.cycle = FakeCycle.new(states: { checkpoint: true }, return_to: "/after")
    @harness.checkpoint_result = Result.new(false)

    @harness.redirect_after_checkpoint_sequence!(pt: "fallback")

    assert_equal "/app/selector?pt=pt%3A%2Fafter&ri=jp", @harness.redirected.first
  end

  test "issue_welcome_gate_and_path sets the gate and clears previous state" do
    @harness.session[@harness.send(:welcome_gate_key)] = { "remaining" => 1 }

    path = @harness.send(:issue_welcome_gate_and_path, pt: "/after", sequence_id: "seq-1")

    assert_equal "/welcome?pt=/after", path
    gate = @harness.session[@harness.send(:welcome_gate_key)]

    assert_equal 5, gate["remaining"]
    assert_equal "seq-1", gate["sequence_id"]
  end

  test "consume_welcome_gate! rejects invalid and mismatched gates and decrements valid ones" do
    gate_key = @harness.send(:welcome_gate_key)

    @harness.session[gate_key] = "bad"

    assert_not @harness.send(:consume_welcome_gate!)

    @harness.session[gate_key] = { "remaining" => 1, "expires_at" => 1.minute.ago.to_i }

    assert_not @harness.send(:consume_welcome_gate!)

    @harness.session[gate_key] = { "remaining" => 0, "expires_at" => 1.minute.from_now.to_i }

    assert_not @harness.send(:consume_welcome_gate!)

    @harness.session[gate_key] = { "remaining" => 1, "expires_at" => 1.minute.from_now.to_i, "sequence_id" => "seq-x" }

    assert_not @harness.send(:consume_welcome_gate!, sequence_id: "seq-y")

    @harness.session[gate_key] = { "remaining" => 2, "expires_at" => 1.minute.from_now.to_i, "sequence_id" => "seq-y" }

    assert @harness.send(:consume_welcome_gate!, sequence_id: "seq-y")
    assert_equal 1, @harness.session[gate_key]["remaining"]
  end

  test "sign_in_sequence_redirect_path follows cycle state branches" do
    @harness.cycle = FakeCycle.new(states: { session_limit: true })

    assert_equal "/app/session?pt=pt%3Apt%3A%2Freturn&ri=jp", @harness.sign_in_sequence_redirect_path

    @harness.cycle = FakeCycle.new(states: { checkpoint: true })

    assert_equal "/checkpoint?pt=pt:/return", @harness.sign_in_sequence_redirect_path

    @harness.cycle = FakeCycle.new(states: { selector: true })

    assert_equal "/app/selector?pt=pt%3Apt%3A%2Freturn&ri=jp", @harness.sign_in_sequence_redirect_path

    @harness.cycle = FakeCycle.new(states: { completed: true })

    assert_equal "/welcome?pt=pt:/return", @harness.sign_in_sequence_redirect_path

    @harness.cycle = FakeCycle.new(states: { guardrail: false })

    assert_equal "/dashboard", @harness.sign_in_sequence_redirect_path

    @harness.cycle = FakeCycle.new(states: { guardrail: true })

    assert_equal "/checkpoint?pt=pt:/return", @harness.sign_in_sequence_redirect_path
  end

  test "continue_selector_sequence! rejects, advances, and rescues selector participant errors" do
    assert_not @harness.continue_selector_sequence!
    assert_equal :bad_request, @harness.rendered[:status]

    @harness.cycle = FakeCycle.new(states: { selector: false })

    assert_not @harness.continue_selector_sequence!
    assert_equal :bad_request, @harness.rendered[:status]

    @harness.cycle = FakeCycle.new(states: { selector: true })
    @harness.allowed_policy = false

    assert_not @harness.continue_selector_sequence!
    assert_equal :bad_request, @harness.rendered[:status]

    @harness.cycle = FakeCycle.new(states: { selector: true }, return_to: "/after")
    @harness.allowed_policy = true
    @harness.current_resource = Client.new(id: 123)
    actor_authn = Struct.new(:login_public_id).new("login-1")

    Actor.stub(:authn, actor_authn) do
      SignInSelectorParticipant.stub(:new, Struct.new(:auto_commit_single!).new(true)) do
        @harness.selector_result = { status: :success }

        @harness.continue_selector_sequence!

        assert_equal "/welcome?pt=/after", @harness.redirected.first
      end

      @harness.cycle = FakeCycle.new(states: { selector: true }, return_to: "/after")
      SignInSelectorParticipant.stub(:new, Struct.new(:auto_commit_single!).new(true)) do
        @harness.selector_result = { status: :failed }

        assert_not @harness.continue_selector_sequence!
        assert_equal :bad_request, @harness.rendered[:status]
      end

      @harness.cycle = FakeCycle.new(states: { selector: true }, return_to: "/after")
      raiser = Object.new
      raiser.define_singleton_method(:auto_commit_single!) { raise SignInSelectorParticipant::Error, "boom" }
      SignInSelectorParticipant.stub(:new, raiser) do
        assert_not @harness.continue_selector_sequence!
        assert_equal :bad_request, @harness.rendered[:status]
      end
    end
  end

  test "dashboard_sequence_step_required? and sign_in_sequence_required_for_participant? default to true" do
    plain_harness = Class.new { include AuthenticationSequenceGate }.new

    assert plain_harness.send(:dashboard_sequence_step_required?)
    assert plain_harness.send(:sign_in_sequence_required_for_participant?, :checkpoint)
  end

  test "begin_sign_in_sequence! returns a success result when current resource is present" do
    @harness.current_resource = Client.new(id: 123)
    @harness.current_session = Struct.new(:id).new(1)

    actor_authn = Struct.new(:amr).new(["pwd"])

    Actor.stub(:authn, actor_authn) do
      result = @harness.send(:begin_sign_in_sequence!, pt: "/settings", checkpoint_required: true)

      assert_equal :success, result.status
      assert_equal 123, result.actor.id
      assert_equal :found, result.response_status
    end
  end

  test "require_sign_in_sequence_participant! renders bad request when policy denies" do
    sequence = Struct.new(:expired?, :state, :actor_type).new(false, "CHECKPOINT_PENDING", "client")
    @harness.allowed_policy = false
    carrier = Class.new do
      attr_accessor :current, :expired, :failed

      def initialize(sequence)
        @current = sequence
      end

      def expire!
        @expired = true
      end

      def fail!
        @failed = true
      end
    end.new(sequence)
    @harness.instance_variable_set(:@sign_in_sequence_carrier, carrier)

    assert_not @harness.send(
      :require_sign_in_sequence_participant!, participant: :checkpoint,
                                              policy_rule: :show_checkpoint?,
    )
    assert_equal :bad_request, @harness.rendered[:status]
  end

  test "enforce_sign_in_selector_gate! renders forbidden for json and redirects for html" do
    @harness.current_resource = Client.new
    @harness.cycle = FakeCycle.new(states: { selector: true })
    @harness.request.format = Struct.new(:html?).new(false)
    @harness.request.path = "/blocked"
    @harness.define_singleton_method(:sign_in_selector_allowed_request?) { false }

    @harness.enforce_sign_in_selector_gate!

    assert_equal :forbidden, @harness.rendered[:status]

    @harness.request.format = Struct.new(:html?).new(true)
    @harness.rendered = nil

    @harness.enforce_sign_in_selector_gate!

    assert_equal ["/app/selector?pt=pt%3A%2Freturn&ri=jp", {}], @harness.redirected
  end

  test "current_db_sign_in_flow_for_sequence returns nil when locator raises argument error" do
    @harness.define_singleton_method(:current_session) { raise ArgumentError }

    assert_nil @harness.send(:current_db_sign_in_flow_for_sequence)
  end

  test "current_db_sign_in_flow_for_sequence resolves pending actors before token issuance" do
    [
      [:app, Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE),
       ClientSignInFlow, :pending_login_user_id,],
      [:com, Visitor.create!(public_id: "v_#{SecureRandom.hex(6)}", status_id: VisitorStatus::ACTIVE),
       VisitorSignInFlow, :pending_login_visitor_id,],
      [:org, Operator.create!(status_id: OperatorStatus::ACTIVE),
       OperatorSignInFlow, :pending_login_staff_id,],
    ].each do |surface, actor, cycle_class, pending_key|
      harness = LocatorHarness.new
      harness.surface = surface
      cycle = create_session_limit_cycle(cycle_class, actor)

      SignInCycleLocator.new(harness.session, surface: surface, actor: actor).issue!(cycle, nonce: "pending-#{surface}")
      harness.session[pending_key] = actor.id

      assert_equal cycle, harness.send(:current_db_sign_in_flow_for_sequence)
    end
  end

  test "continue_checkpoint_sequence_without_content! advances a checkpoint cycle" do
    @harness.current_resource = Client.new(id: 123)
    @harness.cycle = FakeCycle.new(states: { checkpoint: true, dashboard: true }, return_to: "/after")
    @harness.checkpoint_result = Result.new(false)

    issued = []
    @harness.define_singleton_method(:issue_welcome_gate_and_path) do |pt:, sequence_id:|
      issued << [pt, sequence_id]
      "/welcome?pt=#{pt}"
    end

    @harness.continue_checkpoint_sequence_without_content!

    assert_equal [["/after", "seq-1"]], issued
    assert_equal "/welcome?pt=/after", @harness.redirected.first
  end

  test "continue_checkpoint_sequence_without_content! redirects to after_login_path for an OIDC login challenge" do
    @harness.current_resource = Client.new(id: 123)
    @harness.cycle = FakeCycle.new(states: { checkpoint: true, dashboard: true }, return_to: "/after")
    @harness.checkpoint_result = Result.new(false)
    @harness.session[:oidc_authorization_login_challenge] = "challenge-1"
    @harness.define_singleton_method(:after_login_path) { "/after-login" }

    @harness.continue_checkpoint_sequence_without_content!

    assert_equal ["/after-login", { allow_other_host: false }], @harness.redirected
  end

  test "continue_welcome_sequence_without_content! handles non-cycle and cycle paths" do
    carrier =
      Struct.new(:current, :completed, :cleared) do
        def complete!
          self.completed = true
        end

        def clear!
          self.cleared = true
        end
      end.new(Struct.new(:participant).new("dashboard"), false, false)
    @harness.instance_variable_set(:@sign_in_sequence_carrier, carrier)
    @harness.define_singleton_method(:welcome_gate_available?) { true }
    @harness.define_singleton_method(:consume_welcome_gate!) { |**| true }
    @harness.define_singleton_method(:path_target_value) { "/after" }
    @harness.define_singleton_method(:clear_welcome_gate!) { @cleared = true }

    @harness.continue_welcome_sequence_without_content!

    assert carrier.completed
    assert carrier.cleared
    assert_equal "/after", @harness.instance_variable_get(:@welcome_next_path)
  end

  test "start_sign_in_flow_for! stores a cycle with the derived return path" do
    cycle_class =
      Class.new do
        class << self
          def created
            @created
          end

          def created=(val)
            @created = val
          end
        end

        def self.create!(**attrs)
          self.created = attrs
          Struct.new(:id).new(77)
        end

        def self.status_id_for(value)
          "status:#{value}"
        end

        def self.digest_nonce(nonce)
          "digest:#{nonce}"
        end
      end

    @harness.define_singleton_method(:sign_in_flow_class_for) { |_resource| cycle_class }
    @harness.define_singleton_method(:path_from_signed_pt) { |value| value&.sub(/\Apt:/, "") }
    @harness.define_singleton_method(:signed_pt_token) { |value| value && "pt:#{value}" }

    result = @harness.send(:start_sign_in_flow_for!, Client.new(id: 42), pt: "/return")

    created = cycle_class.created

    assert_equal 42, created[:principal_id]
    assert_equal "/return", created[:return_to]
    assert_equal "status:PRIMARY_PENDING", created[:status_id]
    assert_equal 77, result.id
  end

  test "bind_current_session_to_sign_in_flow! skips completed tokens and binds missing ones" do
    cycle = Struct.new(:token_id, :session_issued_at, :updated) do
      def has_attribute?(name)
        %i(token_id session_issued_at).include?(name)
      end

      def reload
        self
      end

      def update!(changes)
        self.updated = changes
      end
    end.new(nil, nil, nil)

    @harness.current_session = "session-1"
    @harness.send(:bind_current_session_to_sign_in_flow!, cycle)

    assert_equal "session-1", cycle.updated[:token]
  end

  test "sign_in_selector_allowed_request? accepts allowed routes and rejects invalid paths" do
    @harness.request.path = "/app/selector"

    assert @harness.send(:sign_in_selector_allowed_request?)

    @harness.request.path = "/unrelated"
    @harness.define_singleton_method(:sign_app_selector_path) { |**| "http://[" }

    assert_not @harness.send(:sign_in_selector_allowed_request?)
  end

  test "sign_in_sequence_surface_for_actor and sign_in_flow_class_for resolve actor types" do
    assert_equal :app, @harness.send(:sign_in_sequence_surface_for_actor, Client.new)
    assert_equal :com, @harness.send(:sign_in_sequence_surface_for_actor, Visitor.new)
    assert_equal :org, @harness.send(:sign_in_sequence_surface_for_actor, Operator.new)
    assert_equal :app, @harness.send(:sign_in_sequence_surface_for_actor, Object.new)

    assert_equal ClientSignInFlow, @harness.send(:sign_in_flow_class_for, Client.new)
    assert_equal VisitorSignInFlow, @harness.send(:sign_in_flow_class_for, Visitor.new)
    assert_equal OperatorSignInFlow, @harness.send(:sign_in_flow_class_for, Operator.new)

    assert_raises(ArgumentError) do
      @harness.send(:sign_in_flow_class_for, Object.new)
    end
  end

  test "issue_active_session_for_selector! issues a session and persists the cycle" do
    cycle_class =
      Class.new do
        class << self
          def transaction
            yield
          end
        end

        attr_reader :updates, :locks, :completed

        def initialize
          @updates = []
          @locks = 0
          @completed = false
        end

        def lock!
          @locks += 1
        end

        def sign_in_completed?
          false
        end

        def sign_in_session_issuance_pending?
          true
        end

        def has_attribute?(name)
          name == :session_issued_at
        end

        def token_id
          nil
        end

        def update!(changes)
          @updates << changes
        end

        def complete_sign_in!
          @completed = true
        end
      end

    cycle = cycle_class.new
    actor = Client.new(id: 101)

    @harness.define_singleton_method(:sign_in_flow_actor) { |_cycle| actor }

    result = AuthenticationSequenceGate.instance_method(:issue_active_session_for_selector!).bind(@harness).call(cycle)

    assert_equal({ status: :success }, result)
    assert_equal 1, cycle.updates.length
    assert_predicate cycle, :completed
    assert_equal({ token: nil }, cycle.updates.first.slice(:token))
    assert_predicate cycle.updates.first[:session_issued_at], :present?
  end

  # The OIDC hand-off promotes a session-limited cycle only once every participant
  # ahead of the hand-off has cleared. A blocking guardrail or checkpoint stops it,
  # and the caller treats that as "do not hand off".
  test "advance_oidc_session_promotion stops at a blocking guardrail" do
    cycle = FakeCycle.new(states: { guardrail: true })
    @harness.guardrail_result = Result.new(true)

    SignInGuardrailParticipant.stub(:new, GuardrailParticipant.new(Result.new(true))) do
      assert_not @harness.send(:advance_oidc_session_promotion!, cycle, Object.new)
    end
  end

  test "advance_oidc_session_promotion stops at a blocking checkpoint" do
    cycle = FakeCycle.new(states: { guardrail: false, checkpoint: true })
    @harness.checkpoint_result = Result.new(true)

    assert_not @harness.send(:advance_oidc_session_promotion!, cycle, Object.new)
  end

  test "advance_oidc_session_promotion clears when no participant blocks" do
    cycle = FakeCycle.new(states: { guardrail: true, checkpoint: true })
    @harness.checkpoint_result = Result.new(false)

    SignInGuardrailParticipant.stub(:new, GuardrailParticipant.new(Result.new(false))) do
      assert @harness.send(:advance_oidc_session_promotion!, cycle, Object.new)
    end
  end

  test "sign_in_sequence_redirect_path returns the default path when the guardrail participant blocks" do
    @harness.cycle = FakeCycle.new(states: { guardrail: true })
    @harness.guardrail_result = Result.new(true)

    assert_equal "/dashboard", @harness.sign_in_sequence_redirect_path
  end

  test "sign_in_session_limit_path and sign_in_selector_path fall back to bare paths without query attributes" do
    fallback = FallbackHarness.new
    fallback.define_singleton_method(:current_region_identifier) { nil }

    assert_equal "/in/session", fallback.sign_in_session_limit_path(pt: nil)
    assert_equal "/selector", fallback.sign_in_selector_path(pt: nil)
  end

  test "continue_checkpoint_sequence_without_content! rejects when the checkpoint show policy denies access" do
    @harness.cycle = FakeCycle.new(states: { checkpoint: true })
    @harness.allowed_policy = false

    @harness.continue_checkpoint_sequence_without_content!

    assert_equal :bad_request, @harness.rendered[:status]
  end

  test "continue_checkpoint_sequence_without_content! binds the active session token when it is missing" do
    @harness.current_resource = Client.new(id: 123)
    @harness.current_session = Struct.new(:id).new(999)
    cycle = FakeCycle.new(states: { checkpoint: true, dashboard: true }, return_to: "/after")
    @harness.cycle = cycle
    @harness.checkpoint_result = Result.new(false)

    @harness.continue_checkpoint_sequence_without_content!

    assert_equal @harness.current_session, cycle.last_update_changes[:token]
  end

  test "continue_checkpoint_sequence_without_content! validates participant requirements when no cycle is active" do
    @harness.define_singleton_method(:signed_pt_param) { "/pt-target" }

    @harness.continue_checkpoint_sequence_without_content!

    assert_equal "/welcome?pt=/pt-target", @harness.redirected.first
  end

  test "continue_checkpoint_sequence_without_content! skips participant validation when it is not required" do
    @harness.define_singleton_method(:sign_in_sequence_required_for_participant?) { |_participant| false }
    @harness.define_singleton_method(:signed_pt_param) { "/pt-target-2" }

    @harness.continue_checkpoint_sequence_without_content!

    assert_equal "/welcome?pt=/pt-target-2", @harness.redirected.first
  end

  test "continue_checkpoint_sequence_without_content! renders bad request when required participant validation fails" do
    @harness.allowed_policy = false

    @harness.continue_checkpoint_sequence_without_content!

    assert_equal :bad_request, @harness.rendered[:status]
    assert_nil @harness.redirected
  end

  test "process_cycle_based_sequence! clears state and redirects home once sign-in is already completed" do
    @harness.cycle = FakeCycle.new(states: { completed: true })
    gate_key = @harness.send(:welcome_gate_key)
    @harness.session[gate_key] = { "remaining" => 1 }

    @harness.continue_welcome_sequence_without_content!

    assert_equal ["/welcome", {}], @harness.redirected
    assert_nil @harness.session[gate_key]
    assert @harness.instance_variable_get(:@locator_cleared)
  end

  test "continue_welcome_sequence_without_content! redirects through pending session-limit and selector states" do
    @harness.cycle = FakeCycle.new(states: { session_limit: true }, return_to: "/limit-return")

    @harness.continue_welcome_sequence_without_content!

    assert_equal "/app/session?pt=pt%3A%2Flimit-return&ri=jp", @harness.redirected.first

    @harness.cycle = FakeCycle.new(states: { selector: true }, return_to: "/selector-return")
    @harness.redirected = nil

    @harness.continue_welcome_sequence_without_content!

    assert_equal "/app/selector?pt=pt%3A%2Fselector-return&ri=jp", @harness.redirected.first
  end

  test "continue_welcome_sequence_without_content! rejects a cycle that is neither dashboard- nor return-pending" do
    @harness.cycle = FakeCycle.new(states: {})

    @harness.continue_welcome_sequence_without_content!

    assert_equal :bad_request, @harness.rendered[:status]
  end

  test "continue_welcome_sequence_without_content! redirects home when the welcome gate cannot be used" do
    @harness.cycle = FakeCycle.new(states: { dashboard: true }, public_id: "seq-gate")

    @harness.continue_welcome_sequence_without_content!

    assert_equal ["/welcome", {}], @harness.redirected

    gate_key = @harness.send(:welcome_gate_key)
    @harness.session[gate_key] = {
      "remaining" => 2,
      "expires_at" => 1.minute.from_now.to_i,
      "sequence_id" => "seq-other",
    }
    @harness.redirected = nil

    @harness.continue_welcome_sequence_without_content!

    assert_equal ["/welcome", {}], @harness.redirected
  end

  test "continue_welcome_sequence_without_content! stops without redirecting when the dashboard participant blocks" do
    cycle = FakeCycle.new(states: { dashboard: true }, public_id: "seq-block")
    @harness.cycle = cycle
    gate_key = @harness.send(:welcome_gate_key)
    @harness.session[gate_key] = {
      "remaining" => 2,
      "expires_at" => 1.minute.from_now.to_i,
      "sequence_id" => "seq-block",
    }
    @harness.current_resource = Client.new(id: 5)
    @harness.guardrail_result = Result.new(true)

    @harness.continue_welcome_sequence_without_content!

    assert_nil @harness.redirected
    assert_nil @harness.instance_variable_get(:@welcome_next_path)
  end

  test "continue_welcome_sequence_without_content! completes a return-pending cycle and skips an unsafe destination" do
    cycle = FakeCycle.new(states: { return_pending: true }, public_id: "seq-return")
    @harness.cycle = cycle
    gate_key = @harness.send(:welcome_gate_key)
    @harness.session[gate_key] = {
      "remaining" => 2,
      "expires_at" => 1.minute.from_now.to_i,
      "sequence_id" => "seq-return",
    }
    @harness.current_resource = Client.new(id: 6)
    @harness.define_singleton_method(:safe_non_welcome_return_path) { |_path| nil }

    SignInReturnParticipant.stub(:new, Struct.new(:consume!).new("/return-target")) do
      @harness.continue_welcome_sequence_without_content!
    end

    assert_nil @harness.instance_variable_get(:@welcome_next_path)
    assert_nil @harness.session[gate_key]
    assert @harness.instance_variable_get(:@locator_cleared)
  end

  test "process_non_cycle_sequence! skips completing the carrier when its participant is not the dashboard step" do
    carrier =
      Struct.new(:current, :completed, :cleared) do
        def complete!
          self.completed = true
        end

        def clear!
          self.cleared = true
        end
      end.new(Struct.new(:participant).new("selector"), false, false)
    @harness.instance_variable_set(:@sign_in_sequence_carrier, carrier)
    @harness.define_singleton_method(:welcome_gate_available?) { true }
    @harness.define_singleton_method(:consume_welcome_gate!) { |**| true }
    @harness.define_singleton_method(:path_target_value) { "/after" }

    @harness.continue_welcome_sequence_without_content!

    assert_not carrier.completed
    assert_equal "/after", @harness.instance_variable_get(:@welcome_next_path)
  end

  test "process_non_cycle_sequence! redirects home when the welcome gate cannot be consumed" do
    carrier = Struct.new(:current).new(Struct.new(:participant).new("selector"))
    @harness.instance_variable_set(:@sign_in_sequence_carrier, carrier)
    @harness.define_singleton_method(:welcome_gate_available?) { true }
    @harness.define_singleton_method(:consume_welcome_gate!) { |**| false }

    @harness.continue_welcome_sequence_without_content!

    assert_equal ["/welcome", {}], @harness.redirected
  end

  test "consume_welcome_gate! clears the gate once the last remaining use is consumed" do
    gate_key = @harness.send(:welcome_gate_key)
    @harness.session[gate_key] = { "remaining" => 1, "expires_at" => 1.minute.from_now.to_i }

    assert @harness.send(:consume_welcome_gate!)
    assert_nil @harness.session[gate_key]
  end

  test "welcome_gate_available? rejects invalid, expired, exhausted, and mismatched gates but accepts a valid one" do
    gate_key = @harness.send(:welcome_gate_key)

    @harness.session[gate_key] = "bad"

    assert_not @harness.send(:welcome_gate_available?)

    @harness.session[gate_key] = { "remaining" => 1, "expires_at" => 1.minute.ago.to_i }

    assert_not @harness.send(:welcome_gate_available?)

    @harness.session[gate_key] = { "remaining" => 0, "expires_at" => 1.minute.from_now.to_i }

    assert_not @harness.send(:welcome_gate_available?)

    @harness.session[gate_key] = { "remaining" => 1, "expires_at" => 1.minute.from_now.to_i, "sequence_id" => "seq-x" }

    assert_not @harness.send(:welcome_gate_available?, sequence_id: "seq-y")
    assert_nil @harness.session[gate_key]

    @harness.session[gate_key] = { "remaining" => 1, "expires_at" => 1.minute.from_now.to_i, "sequence_id" => "seq-y" }

    assert @harness.send(:welcome_gate_available?, sequence_id: "seq-y")
    assert_equal 1, @harness.session[gate_key]["remaining"]
  end

  test "enforce_sign_in_selector_gate! does nothing when the current request is already an allowed selector request" do
    @harness.current_resource = Client.new
    @harness.cycle = FakeCycle.new(states: { selector: true })
    @harness.request.path = "/app/selector"

    @harness.enforce_sign_in_selector_gate!

    assert_nil @harness.rendered
    assert_nil @harness.redirected
  end

  test "sign_in_guardrail_participant builds a real guardrail participant bound to the resolved actor" do
    actor = Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE)
    @harness.current_resource = actor
    cycle = FakeCycle.new

    participant = AuthenticationSequenceGate.instance_method(:sign_in_guardrail_participant).bind(@harness).call(cycle)

    assert_instance_of SignInGuardrailParticipant, participant
  end

  test "clear_current_sign_in_flow_locator! swallows an ArgumentError raised while resolving the locator" do
    @harness.define_singleton_method(:sign_in_flow_locator_for) { |**_kwargs| raise ArgumentError }

    result = AuthenticationSequenceGate.instance_method(:clear_current_sign_in_flow_locator!).bind(@harness).call

    assert_nil result
  end

  test "begin_sign_in_sequence! returns nil without starting a sequence when there is no current resource" do
    @harness.current_resource = nil

    assert_nil @harness.send(:begin_sign_in_sequence!, pt: "/x", checkpoint_required: false)
  end

  test "begin_sign_in_sequence! falls back to an unknown auth method when the actor reports no amr" do
    @harness.current_resource = Client.new(id: 321)
    actor_authn = Struct.new(:amr).new(nil)

    Actor.stub(:authn, actor_authn) do
      result = @harness.send(:begin_sign_in_sequence!, pt: "/settings", checkpoint_required: false)

      assert_equal :success, result.status
    end
  end

  test "require_sign_in_sequence_participant! returns true immediately when the policy allows the participant" do
    sequence = Struct.new(:expired?, :state, :actor_type).new(false, "CHECKPOINT_PENDING", "client")
    carrier = Struct.new(:current).new(sequence)
    @harness.instance_variable_set(:@sign_in_sequence_carrier, carrier)
    @harness.allowed_policy = true

    assert @harness.send(
      :require_sign_in_sequence_participant!, participant: :checkpoint,
                                              policy_rule: :show_checkpoint?,
    )
  end

  test "require_sign_in_sequence_participant! expires an already-expired sequence before rejecting it" do
    sequence = Struct.new(:expired?, :state, :actor_type).new(true, "CHECKPOINT_PENDING", "client")
    carrier =
      Class.new do
        attr_accessor :current, :expired, :failed

        def initialize(sequence)
          @current = sequence
        end

        def expire!
          @expired = true
        end

        def fail!
          @failed = true
        end
      end.new(sequence)
    @harness.instance_variable_set(:@sign_in_sequence_carrier, carrier)
    @harness.allowed_policy = false

    assert_not @harness.send(
      :require_sign_in_sequence_participant!, participant: :checkpoint,
                                              policy_rule: :show_checkpoint?,
    )
    assert carrier.expired
    assert_not carrier.failed
  end

  test "require_sign_in_sequence_participant! logs a rejection without a sequence when none is active" do
    carrier = Struct.new(:current).new(nil)
    @harness.instance_variable_set(:@sign_in_sequence_carrier, carrier)
    @harness.allowed_policy = false

    assert_not @harness.send(
      :require_sign_in_sequence_participant!, participant: :checkpoint,
                                              policy_rule: :show_checkpoint?,
    )
    assert_equal :bad_request, @harness.rendered[:status]
  end

  test "current_db_sign_in_flow_for_sequence treats a missing current_session reader as no active token" do
    harness = NoCurrentSessionHarness.new

    assert_nil harness.send(:current_db_sign_in_flow_for_sequence)
  end

  test "sign_in_flow_actor falls back to the cycle principal when no resource is signed in" do
    @harness.current_resource = nil
    cycle = Struct.new(:principal).new(Struct.new(:id).new(99))

    actor = AuthenticationSequenceGate.instance_method(:sign_in_flow_actor).bind(@harness).call(cycle)

    assert_equal 99, actor.id
  end

  test "sign_in_flow_actor returns nil when the cycle has no principal association" do
    @harness.current_resource = nil
    cycle = Object.new

    actor = AuthenticationSequenceGate.instance_method(:sign_in_flow_actor).bind(@harness).call(cycle)

    assert_nil actor
  end

  test "bind_current_session_to_sign_in_flow! does nothing when the cycle lacks a token_id attribute" do
    cycle = Class.new { def has_attribute?(_name) = false }.new

    assert_nil @harness.send(:bind_current_session_to_sign_in_flow!, cycle)
  end

  test "bind_current_session_to_sign_in_flow! does nothing when there is no current session" do
    cycle =
      Class.new do
        def has_attribute?(name) = name == :token_id

        def token_id = nil
      end.new
    @harness.current_session = nil

    assert_nil @harness.send(:bind_current_session_to_sign_in_flow!, cycle)
  end

  test "bind_current_session_to_sign_in_flow! binds the token without a session_issued_at write when unsupported" do
    cycle =
      Class.new do
        attr_accessor :updated

        def has_attribute?(name) = name == :token_id

        def token_id = nil

        def reload = self

        def update!(changes) = self.updated = changes
      end.new
    @harness.current_session = "session-xyz"

    @harness.send(:bind_current_session_to_sign_in_flow!, cycle)

    assert_equal({ token: "session-xyz" }, cycle.updated)
  end

  test "advance_pending_sign_in_flow_after_primary! returns the result unchanged for an unpersisted cycle" do
    result = { status: :ok }

    returned = @harness.send(:advance_pending_sign_in_flow_after_primary!, nil, Client.new, result)

    assert_same result, returned
  end

  test "advance_pending_sign_in_flow_after_primary! skips the session-limit transition once past primary or mfa" do
    actor = Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE)
    cycle = @harness.send(:start_sign_in_flow_for!, actor, pt: "/after")
    cycle.advance_sign_in_to_guardrail!
    result = { status: :ok, session_management_required: true }

    returned = @harness.send(:advance_pending_sign_in_flow_after_primary!, cycle, actor, result)

    assert_equal result, returned
    assert_predicate cycle.reload, :sign_in_guardrail_pending?
  end

  test "advance_pending_sign_in_flow_after_primary! skips the guardrail transition once past that step" do
    actor = Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE)
    cycle = @harness.send(:start_sign_in_flow_for!, actor, pt: "/after")
    cycle.advance_sign_in_to_guardrail!
    cycle.advance_sign_in_to_checkpoint!
    result = { status: :ok }

    returned = @harness.send(:advance_pending_sign_in_flow_after_primary!, cycle, actor, result)

    assert_equal result, returned
    assert_predicate cycle.reload, :sign_in_checkpoint_pending?
  end

  test "advance_cycle_to_checkpoint_after_active_session! advances a primary-pending cycle and binds the token" do
    actor = Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE)
    cycle = @harness.send(:start_sign_in_flow_for!, actor, pt: "/after")
    token = ClientToken.create!(user: actor)

    @harness.send(:advance_cycle_to_checkpoint_after_active_session!, cycle, actor, token)

    reloaded = cycle.reload

    assert_predicate reloaded, :sign_in_checkpoint_pending?
    assert_equal token.id, reloaded.token_id
  end

  test "advance_cycle_to_checkpoint_after_active_session! skips already-cleared steps for a " \
       "session-issuance-pending cycle" do
    cycle =
      Class.new do
        attr_accessor :advanced_to_checkpoint, :token_id

        def sign_in_primary_pending? = false

        def sign_in_mfa_pending? = false

        def sign_in_guardrail_pending? = false

        def reload = self

        def sign_in_session_issuance_pending? = true

        def advance_sign_in_to_checkpoint!
          self.advanced_to_checkpoint = true
        end
      end.new
    cycle.token_id = 123
    actor = Client.new(id: 1)
    token = Struct.new(:id).new(999)

    @harness.send(:advance_cycle_to_checkpoint_after_active_session!, cycle, actor, token)

    assert cycle.advanced_to_checkpoint
    assert_equal 123, cycle.token_id
  end

  test "promote_current_session_limit_cycle_for_oidc_handoff! returns nil when there is no active cycle at all" do
    @harness.cycle = nil
    @harness.session[:oidc_authorization_login_challenge] = "chal-none"

    assert_nil @harness.send(
      :promote_current_session_limit_cycle_for_oidc_handoff!, Client.new,
      auth_method: "email",
    )
  end

  test "issue_active_session_for_selector! returns invalid_request when the cycle is not session-issuance pending" do
    cycle_class =
      Class.new do
        class << self
          def transaction
            yield
          end
        end

        def lock! = nil

        def sign_in_completed? = false

        def sign_in_session_issuance_pending? = false

        def token_id = nil
      end
    cycle = cycle_class.new
    actor = Client.new(id: 55)
    @harness.define_singleton_method(:sign_in_flow_actor) { |_cycle| actor }

    result = AuthenticationSequenceGate.instance_method(:issue_active_session_for_selector!).bind(@harness).call(cycle)

    assert_equal({ status: :invalid_request }, result)
  end

  test "issue_active_session_for_selector! returns the failed session result when log_in does not succeed" do
    cycle_class =
      Class.new do
        class << self
          def transaction
            yield
          end
        end

        def lock! = nil

        def sign_in_completed? = false

        def sign_in_session_issuance_pending? = true

        def token_id = nil
      end
    cycle = cycle_class.new
    actor = Client.new(id: 56)
    @harness.define_singleton_method(:sign_in_flow_actor) { |_cycle| actor }
    @harness.define_singleton_method(:log_in) { |*_args, **_kwargs| { status: :failed } }

    result = AuthenticationSequenceGate.instance_method(:issue_active_session_for_selector!).bind(@harness).call(cycle)

    assert_equal({ status: :failed }, result)
  end

  test "issue_active_session_for_selector! returns early when the cycle completes with a matching token mid-flight" do
    cycle_class =
      Class.new do
        class << self
          def transaction
            yield
          end
        end

        attr_accessor :sign_in_completed_flag, :token_id

        def lock! = nil

        def sign_in_completed? = sign_in_completed_flag

        def sign_in_session_issuance_pending? = true
      end
    cycle = cycle_class.new
    cycle.sign_in_completed_flag = false
    cycle.token_id = nil
    actor = Client.new(id: 57)
    session_token = Struct.new(:id).new(777)
    @harness.current_session = session_token
    @harness.define_singleton_method(:sign_in_flow_actor) { |_cycle| actor }
    @harness.define_singleton_method(:log_in) do |*_args, **_kwargs|
      cycle.sign_in_completed_flag = true
      cycle.token_id = 777
      { status: :success }
    end

    result = AuthenticationSequenceGate.instance_method(:issue_active_session_for_selector!).bind(@harness).call(cycle)

    assert_equal({ status: :success }, result)
  end

  test "issue_active_session_for_selector! returns invalid_request when the cycle leaves issuance pending mid-flight" do
    cycle_class =
      Class.new do
        class << self
          def transaction
            yield
          end
        end

        attr_accessor :session_issuance_pending_flag, :token_id

        def lock! = nil

        def sign_in_completed? = false

        def sign_in_session_issuance_pending? = session_issuance_pending_flag
      end
    cycle = cycle_class.new
    cycle.session_issuance_pending_flag = true
    cycle.token_id = nil
    actor = Client.new(id: 58)
    @harness.current_session = Struct.new(:id).new(888)
    @harness.define_singleton_method(:sign_in_flow_actor) { |_cycle| actor }
    @harness.define_singleton_method(:log_in) do |*_args, **_kwargs|
      cycle.session_issuance_pending_flag = false
      { status: :success }
    end

    result = AuthenticationSequenceGate.instance_method(:issue_active_session_for_selector!).bind(@harness).call(cycle)

    assert_equal({ status: :invalid_request }, result)
  end

  test "issue_active_session_for_selector! completes the cycle without a session_issued_at write when unsupported" do
    cycle_class =
      Class.new do
        class << self
          def transaction
            yield
          end
        end

        attr_reader :updates

        def initialize
          @updates = []
        end

        def lock! = nil

        def sign_in_completed? = false

        def sign_in_session_issuance_pending? = true

        def has_attribute?(_name) = false

        def token_id = nil

        def update!(changes) = @updates << changes

        def complete_sign_in! = true
      end
    cycle = cycle_class.new
    actor = Client.new(id: 59)
    @harness.define_singleton_method(:sign_in_flow_actor) { |_cycle| actor }

    result = AuthenticationSequenceGate.instance_method(:issue_active_session_for_selector!).bind(@harness).call(cycle)

    assert_equal({ status: :success }, result)
    assert_not cycle.updates.first.key?(:session_issued_at)
  end

  test "advance_oidc_session_promotion! blocks when the guardrail participant flags the actor" do
    actor = Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::RESERVED)
    cycle = @harness.send(:start_sign_in_flow_for!, actor, pt: "/after")
    cycle.advance_sign_in_to_guardrail!

    result = @harness.send(:advance_oidc_session_promotion!, cycle, actor)

    assert_not result
  end

  test "advance_oidc_session_promotion! clears a guardrail-pending cycle and defers to the checkpoint participant" do
    actor = Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE)
    cycle = @harness.send(:start_sign_in_flow_for!, actor, pt: "/after")
    cycle.advance_sign_in_to_guardrail!
    @harness.checkpoint_result = Result.new(false)

    result = @harness.send(:advance_oidc_session_promotion!, cycle, actor)

    assert result
    assert_predicate cycle.reload, :sign_in_checkpoint_pending?
  end

  test "advance_oidc_session_promotion! returns true once the cycle is already past guardrail and checkpoint" do
    actor = Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE)
    cycle = @harness.send(:start_sign_in_flow_for!, actor, pt: "/after")
    cycle.advance_sign_in_to_guardrail!
    cycle.advance_sign_in_to_checkpoint!
    cycle.advance_sign_in_to_selector!

    result = @harness.send(:advance_oidc_session_promotion!, cycle, actor)

    assert result
  end

  test "advance_oidc_session_promotion! returns false when the checkpoint participant blocks the actor" do
    actor = Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE)
    cycle = @harness.send(:start_sign_in_flow_for!, actor, pt: "/after")
    cycle.advance_sign_in_to_guardrail!
    @harness.checkpoint_result = Result.new(true)

    result = @harness.send(:advance_oidc_session_promotion!, cycle, actor)

    assert_not result
  end

  test "bind_session_and_register_oidc! persists dashboard state and registers the OIDC transaction" do
    actor = Client.create!(public_id: "u_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE)
    cycle = @harness.send(:start_sign_in_flow_for!, actor, pt: "/after")
    cycle.advance_sign_in_to_guardrail!
    issued_session = ClientToken.create!(user: actor)
    @harness.session[:oidc_authorization_login_challenge] = "challenge-123"
    # `bind_session_and_register_oidc!` calls `BaseAuthAdmissionCoordinator.register_result_and_issue_resume!`
    # directly (not `OidcAuthorizationTransactionCoordinator.register_result!`, which that method calls
    # internally and then feeds through the real `issue_result!`/`resume_url` computation) -- so the double
    # has to match `BaseAuthAdmissionCoordinator::Issuance`'s three fields at that same layer, or the real
    # downstream `resume_url` computation runs against a fake transaction and the literal URL below can
    # never come back out.
    issuance = BaseAuthAdmissionCoordinator::Issuance.new(
      transaction: nil, code: nil,
      resume_url: "https://resume.example/finish",
    )

    resume_url =
      BaseAuthAdmissionCoordinator.stub(:register_result_and_issue_resume!, issuance) do
        @harness.send(:bind_session_and_register_oidc!, cycle, actor, "challenge-123", "email", issued_session)
      end

    assert_equal "https://resume.example/finish", resume_url
    assert_predicate cycle.reload, :sign_in_dashboard_pending?
    assert_nil @harness.session[:oidc_authorization_login_challenge]
  end

  test "bind_session_and_register_oidc! skips the session_issued_at write when the cycle lacks that attribute" do
    cycle =
      Class.new do
        attr_accessor :updated

        def has_attribute?(name) = name == :token_id

        def reload = self

        def update!(changes) = self.updated = changes

        def status_id_for(value) = "status:#{value}"
      end.new
    actor = Client.new(id: 42)
    issued_session = Struct.new(:public_id).new("session-public-2")
    # Same layer correction as the test above: stub the method `bind_session_and_register_oidc!` actually
    # calls, with a double matching `BaseAuthAdmissionCoordinator::Issuance`'s real fields.
    issuance = BaseAuthAdmissionCoordinator::Issuance.new(
      transaction: nil, code: nil,
      resume_url: "https://resume.example/finish-2",
    )

    resume_url =
      BaseAuthAdmissionCoordinator.stub(:register_result_and_issue_resume!, issuance) do
        @harness.send(:bind_session_and_register_oidc!, cycle, actor, "challenge-456", "email", issued_session)
      end

    assert_equal "https://resume.example/finish-2", resume_url
    assert_not cycle.updated.key?(:session_issued_at)
  end

  test "promote_current_session_limit_cycle_for_oidc_handoff! returns nil when no cycle is session-limit pending" do
    @harness.cycle = FakeCycle.new(states: { session_limit: false })
    @harness.session[:oidc_authorization_login_challenge] = "chal"

    assert_nil @harness.send(
      :promote_current_session_limit_cycle_for_oidc_handoff!, Client.new,
      auth_method: "email",
    )
  end

  test "promote_current_session_limit_cycle_for_oidc_handoff! returns nil without a pending OIDC login challenge" do
    @harness.cycle = FakeCycle.new(states: { session_limit: true })
    @harness.session.delete(:oidc_authorization_login_challenge)

    assert_nil @harness.send(
      :promote_current_session_limit_cycle_for_oidc_handoff!, Client.new,
      auth_method: "email",
    )
  end

  test "promote_current_session_limit_cycle_for_oidc_handoff! returns nil when oidc promotion cannot advance" do
    @harness.cycle = FakeCycle.new(states: { session_limit: true })
    @harness.session[:oidc_authorization_login_challenge] = "chal-1"
    actor = Client.new(id: 7)
    fake_result = Struct.new(:cycle).new(FakeCycle.new(states: { session_limit: true }))
    @harness.define_singleton_method(:advance_oidc_session_promotion!) { |_cycle, _actor| false }

    resume_url =
      SignInSessionLimitManager.stub(:new, Struct.new(:promote!).new(fake_result)) do
        @harness.send(:promote_current_session_limit_cycle_for_oidc_handoff!, actor, auth_method: "email")
      end

    assert_nil resume_url
  end

  test "promote_current_session_limit_cycle_for_oidc_handoff! returns nil when log_in does not succeed" do
    @harness.cycle = FakeCycle.new(states: { session_limit: true })
    @harness.session[:oidc_authorization_login_challenge] = "chal-2"
    actor = Client.new(id: 8)
    fake_result = Struct.new(:cycle).new(FakeCycle.new(states: { session_limit: true }))
    @harness.define_singleton_method(:advance_oidc_session_promotion!) { |_cycle, _actor| true }
    @harness.define_singleton_method(:log_in) { |*_args, **_kwargs| { status: :failed } }

    resume_url =
      SignInSessionLimitManager.stub(:new, Struct.new(:promote!).new(fake_result)) do
        @harness.send(:promote_current_session_limit_cycle_for_oidc_handoff!, actor, auth_method: "email")
      end

    assert_nil resume_url
  end

  test "promote_current_session_limit_cycle_for_oidc_handoff! hands off to bind_session_and_register_oidc! on " \
       "success" do
    @harness.cycle = FakeCycle.new(states: { session_limit: true })
    @harness.session[:oidc_authorization_login_challenge] = "chal-3"
    actor = Client.new(id: 9)
    fake_result = Struct.new(:cycle).new(FakeCycle.new(states: { session_limit: true }))
    @harness.define_singleton_method(:advance_oidc_session_promotion!) { |_cycle, _actor| true }
    @harness.current_session = Struct.new(:id, :public_id).new(1, "session-pub")
    @harness.define_singleton_method(:bind_session_and_register_oidc!) do |_cycle, _actor, challenge, auth_method,
      issued_session|
      ["bound", challenge, auth_method, issued_session]
    end

    resume_url =
      SignInSessionLimitManager.stub(:new, Struct.new(:promote!).new(fake_result)) do
        @harness.send(:promote_current_session_limit_cycle_for_oidc_handoff!, actor, auth_method: "email")
      end

    assert_equal ["bound", "chal-3", "email", @harness.current_session], resume_url
  end

  test "issue_active_session_for_selector! returns invalid_request when no actor resolves for the cycle" do
    cycle = FakeCycle.new
    @harness.define_singleton_method(:sign_in_flow_actor) { |_cycle| nil }

    result = AuthenticationSequenceGate.instance_method(:issue_active_session_for_selector!).bind(@harness).call(cycle)

    assert_equal({ status: :invalid_request }, result)
  end

  test "issue_active_session_for_selector! returns success immediately for an already completed cycle" do
    cycle_class =
      Class.new do
        class << self
          def transaction
            yield
          end
        end

        def lock! = nil

        def sign_in_completed? = true

        def token_id = 55
      end
    cycle = cycle_class.new
    actor = Client.new(id: 202)
    @harness.define_singleton_method(:sign_in_flow_actor) { |_cycle| actor }

    result = AuthenticationSequenceGate.instance_method(:issue_active_session_for_selector!).bind(@harness).call(cycle)

    assert_equal({ status: :success }, result)
  end

  private

  def create_session_limit_cycle(cycle_class, actor)
    cycle_class.create!(
      principal_id: actor.id,
      status_id: cycle_class.status_id_for("SESSION_LIMIT_PENDING"),
      state: "SESSION_LIMIT_PENDING",
      step: "session_limit",
      return_to: "/dashboard",
      nonce_digest: cycle_class.digest_nonce("unused"),
      issued_at: Time.current,
      expires_at: 15.minutes.from_now,
    )
  end
end

# DAMP local route helper aliases for former shared test support.
class AuthenticationSequenceGateExtraCoverageTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end
