# typed: false
# frozen_string_literal: true

require "test_helper"

# Push Line/Branch/Method toward the next whole .0% thresholds.
class BranchCoverageBatch40LinePushTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Edit::Org ApplicationController host and preference helpers" do
    controller = Edit::Org::ApplicationController.new
    controller.define_singleton_method(:base_org_verification_path) { |**kwargs| kwargs }
    ENV["PUBLIC_AUTH_STAFF_URL"] ||= "auth.org.localhost"
    ENV["PUBLIC_BASE_STAFF_URL"] ||= "base.org.localhost"

    assert_not controller.send(:chrome_preference_surface?)
    assert_equal ENV.fetch("PUBLIC_AUTH_STAFF_URL"), controller.send(:oidc_sign_host)
    assert_equal ENV.fetch("PUBLIC_BASE_STAFF_URL"), controller.send(:oidc_acme_host)
    assert_equal ENV.fetch("PUBLIC_BASE_STAFF_URL"), controller.send(:oidc_base_host)
    assert_equal ENV.fetch("PUBLIC_BASE_STAFF_URL"), controller.send(:oidc_base_authority_host)
    assert_equal({ ri: "jp" }, controller.send(:actor_verification_path, ri: "jp"))
    assert controller.send(:cross_host_redirect_allowed?)
    assert_equal "edit-org", controller.send(:oidc_client_id)
    assert_equal "edit/org/publishing", controller.send(:publishing_management_namespace)
  end

  test "Edit::Org HelperMethods delegates execute when signed out" do
    controller = Edit::Org::ApplicationController.new
    controller.define_singleton_method(:current_resource) { nil }
    proxy = Object.new
    proxy.define_singleton_method(:controller) { controller }
    proxy.extend(Edit::Org::ApplicationController::HelperMethods)

    Edit::Org::ApplicationController::HelperMethods.instance_methods(false).each do |method_name|
      assert_nothing_raised { proxy.public_send(method_name) }
    end
  ensure
    Actor.reset
  end

  test "OIDC callback controllers expose client ids and RP class attributes" do
    classes = [
      Auth::App::Oidc::CallbacksController,
      Auth::Com::Oidc::CallbacksController,
      Auth::Org::Oidc::CallbacksController,
      Base::App::Oidc::CallbacksController,
      Base::Com::Oidc::CallbacksController,
      Base::Org::Oidc::CallbacksController,
      Core::App::Oidc::CallbacksController,
      Core::Com::Oidc::CallbacksController,
      Core::Org::Oidc::CallbacksController,
      Edit::Org::Oidc::CallbacksController,
      Side::App::Oidc::CallbacksController,
      Side::Com::Oidc::CallbacksController,
      Side::Org::Oidc::CallbacksController,
    ]
    classes.each do |klass|
      %i(
        oidc_rp_actor_class_name oidc_rp_identity_class_name oidc_rp_bridge_class_name
        oidc_rp_actor_class_name? oidc_rp_identity_class_name? oidc_rp_bridge_class_name?
      ).each do |method_name|
        next unless klass.respond_to?(method_name)

        assert_nothing_raised { klass.public_send(method_name) }
      end
      next unless klass.private_method_defined?(:oidc_client_id) || klass.method_defined?(:oidc_client_id)

      assert_kind_of String, klass.new.send(:oidc_client_id)
    end
  end

  test "Core API base controllers expose resource collaborators" do
    [
      Core::App::Api::V0::BaseController,
      Core::Com::Api::V0::BaseController,
      Core::Org::Api::V0::BaseController,
    ].each do |klass|
      controller = klass.new

      assert_includes %i(app com org), controller.send(:core_actor_tld)
      assert controller.send(:core_resource_class)
      assert controller.send(:core_token_class)
      assert_kind_of String, controller.send(:core_resource_type)
    end
  end

  test "Side application HelperMethods delegates execute" do
    [
      Side::App::ApplicationController,
      Side::Com::ApplicationController,
      Side::Org::ApplicationController,
    ].each do |klass|
      controller = klass.new
      controller.define_singleton_method(:current_resource) { nil }
      proxy = Object.new
      proxy.define_singleton_method(:controller) { controller }
      proxy.extend(klass.const_get(:HelperMethods, false))

      klass.const_get(:HelperMethods, false).instance_methods(false).each do |method_name|
        assert_nothing_raised { proxy.public_send(method_name) }
      end
    end
  ensure
    Actor.reset
  end

  test "Edit::Org Sign::OutsController confirmation helpers and actions" do
    controller = Edit::Org::Sign::OutsController.new
    controller.define_singleton_method(:sign_out_post_path) { "/sign/out" }

    assert_equal "/sign/out", controller.send(:sign_out_confirmation_form_path)

    redirects = []
    renders = []
    controller.define_singleton_method(:complete_oidc_rp_logout!) { redirects << :complete }
    controller.define_singleton_method(:sign_out_edit_path) { "/sign/out/edit" }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:render) { |*args, **kwargs| renders << [args, kwargs] }
    controller.define_singleton_method(:launch_oidc_rp_logout!) { |**kwargs| redirects << kwargs }

    controller.show
    controller.new
    controller.edit
    controller.create

    assert_includes redirects, :complete
    assert_predicate renders, :any?
    assert_operator redirects.size, :>=, 3
  end

  test "DiagnosticSurfaceCredentials guard fails closed and compares securely" do
    blank_source = Object.new
    blank_source.define_singleton_method(:option) { |_| nil }
    blocked = DiagnosticSurfaceCredentials.guard(
      user_key: :u, password_key: :p, credentials: blank_source,
    )

    assert_not blocked.call("u", "p")

    source = Object.new
    source.define_singleton_method(:option) do |key|
      { u: "alice", p: "secret" }.fetch(key)
    end
    guard = DiagnosticSurfaceCredentials.guard(user_key: :u, password_key: :p, credentials: source)

    assert guard.call("alice", "secret")
    assert_not guard.call("alice", "wrong")
    assert_not guard.call("bob", "secret")
  end

  test "RailsPerformanceRecordSanitizer RequestRecordPatch save redacts fields" do
    record = Object.new
    record.instance_variable_set(:@path, "/x?token=1")
    record.instance_variable_set(:@http_referer, "https://ex.example/cb?code=abc")
    record.instance_variable_set(:@exception, "RuntimeError leaked")
    record.extend(RailsPerformanceRecordSanitizer::RequestRecordPatch)
    record.define_singleton_method(:save) { :saved }
    # Prepend-style: call the patch method via unbound binding
    Module.new do
      include RailsPerformanceRecordSanitizer::RequestRecordPatch
    end
    host =
      Class.new do
        attr_accessor :path, :http_referer, :exception

        def save = :saved
      end
    obj = host.new
    obj.path = "/sign/in?code=1"
    obj.http_referer = "https://auth.example/cb?code=xyz"
    obj.exception = "RuntimeError token=secret"
    obj.singleton_class.prepend(RailsPerformanceRecordSanitizer::RequestRecordPatch)
    # Patch uses @path ivars; set those too
    obj.instance_variable_set(:@path, obj.path)
    obj.instance_variable_set(:@http_referer, obj.http_referer)
    obj.instance_variable_set(:@exception, obj.exception)

    assert_equal :saved, obj.save
    assert_equal "/sign/in", obj.instance_variable_get(:@path)
    assert_not_includes obj.instance_variable_get(:@http_referer).to_s, "code=xyz"
    assert_equal "RuntimeError", obj.instance_variable_get(:@exception)
  end

  test "EnforcementReconciliationJob private appeal and failure paths" do
    job = EnforcementReconciliationJob.new
    logged = []
    Rails.logger.stub(:error, ->(msg) { logged << msg }) do
      job.send(:log_failure, "case-1", StandardError.new("boom"))
    end

    assert_predicate logged, :any?

    # nil enforcement_case short-circuit
    appeal = Object.new
    appeal.define_singleton_method(:enforcement_case) { nil }

    assert_nil job.send(:reconcile_appeal!, appeal)

    # approved with ended_at present -> reconcile
    called = []
    enforcement_case = Object.new
    enforcement_case.define_singleton_method(:ended_at) { Time.current }
    enforcement_case.define_singleton_method(:write_audit_event_once!) { |event| called << event }
    appeal = Object.new
    appeal.define_singleton_method(:enforcement_case) { enforcement_case }
    appeal.define_singleton_method(:state) { "approved" }
    appeal.define_singleton_method(:reviewer_operator_public_id) { "op-1" }
    appeal.define_singleton_method(:public_id) { "appeal-1" }

    op = Object.new
    op.define_singleton_method(:reconcile) { called << :reconcile }
    EnforcementCaseEndOperation.stub(:new, ->(**_kwargs) { op }) do
      job.send(:reconcile_appeal!, appeal)
    end

    assert_includes called, :reconcile
    assert_includes called, "appeal_approved"

    # approved without ended_at -> call
    called.clear
    enforcement_case = Object.new
    enforcement_case.define_singleton_method(:ended_at) { nil }
    enforcement_case.define_singleton_method(:write_audit_event_once!) { |event| called << event }
    appeal = Object.new
    appeal.define_singleton_method(:enforcement_case) { enforcement_case }
    appeal.define_singleton_method(:state) { "approved" }
    appeal.define_singleton_method(:reviewer_operator_public_id) { "op-1" }
    appeal.define_singleton_method(:public_id) { "appeal-2" }
    EnforcementCaseEndOperation.stub(:call, ->(**_kwargs) { called << :call }) do
      job.send(:reconcile_appeal!, appeal)
    end

    assert_includes called, :call

    # rescue path for ended case
    bad_case = Object.new
    bad_case.define_singleton_method(:end_reason) { "x" }
    bad_case.define_singleton_method(:ended_by_operator_public_id) { "op" }
    bad_case.define_singleton_method(:public_id) { "case-x" }

    EnforcementCaseEndOperation.stub(:new, ->(**_kwargs) { raise StandardError, "nope" }) do
      assert_nothing_raised { job.send(:reconcile_ended_case!, bad_case) }
    end
  end

  test "OidcClientRegistry public_host? arms" do
    assert_not OidcClientRegistry.send(:public_host?, nil)
    assert_not OidcClientRegistry.send(:public_host?, "")
    assert_not OidcClientRegistry.send(:public_host?, "localhost")
    assert OidcClientRegistry.send(:public_host?, "accounts.example.com")
  end

  test "SignInSequence readers expose payload fields" do
    sequence = SignInSequence.new(
      "method" => "passkey",
      "pt" => "/home",
      "safe_pt_path" => "/home",
      "mfa_challenge_id" => "mfa-1",
      "session_limit_gate_id" => "gate-1",
      "restricted_login_public_id" => "rl-1",
    )

    assert_equal "passkey", sequence.method
    assert_equal "/home", sequence.pt
    assert_equal "/home", sequence.safe_pt_path
    assert_equal "mfa-1", sequence.mfa_challenge_id
    assert_equal "gate-1", sequence.session_limit_gate_id
    assert_equal "rl-1", sequence.restricted_login_public_id
  end
end
