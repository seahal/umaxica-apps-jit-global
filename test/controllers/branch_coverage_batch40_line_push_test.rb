# typed: false
# frozen_string_literal: true

require "test_helper"

# Push Line/Branch/Method toward the next whole .0% thresholds.
class BranchCoverageBatch40LinePushTest < ActiveSupport::TestCase
  self.fixture_table_names = []

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

  test "Warp application HelperMethods delegates execute" do
    [
      Warp::App::ApplicationController,
      Warp::Com::ApplicationController,
      Warp::Org::ApplicationController,
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
