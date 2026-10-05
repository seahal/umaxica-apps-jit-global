# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class VerificationBaseStepUpLoggingTest < ActiveSupport::TestCase
  Request =
    Struct.new(:request_method, :format, keyword_init: true) do
      def get? = false

      def head? = false
    end

  Format =
    Struct.new(:value) do
      def to_s = value

      def json? = false
    end

  Token =
    Struct.new(
      :public_id,
      :last_step_up_at,
      :last_step_up_scope,
      :last_step_up_aal,
      :last_step_up_method,
      :last_step_up_session_public_id,
      :last_step_up_purpose,
      :last_step_up_audience,
      keyword_init: true,
    ) do
      def currently_usable?(_now = Time.current) = true

      def has_attribute?(name)
        members.include?(name.to_sym)
      end
    end

  class Harness
    class << self
      def before_action(*) = nil

      def helper_method(*) = nil
    end

    include CommonRedirect
    include VerificationBase

    attr_accessor :session_token

    def request = Request.new(request_method: "POST", format: Format.new("text/html"))

    def params = {}.with_indifferent_access

    def action_name = "update"

    def current_session_token = session_token

    def enforce_step_up_prereqs!(*) = false

    def render(*) = nil

    def log_out = nil
  end

  setup do
    Actor.reset
    Actor.install_context!(tld: :app, actor_type: :client)
  end

  teardown { Actor.reset }

  test "require_step_up logs diagnostic fields without token identifiers" do
    token = Token.new(
      public_id: "session-public-id-must-not-be-logged",
      last_step_up_at: 1.minute.ago,
      last_step_up_scope: "settings_email",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: "session-public-id-must-not-be-logged",
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
    )
    harness = Harness.new
    harness.session_token = token
    logs = []

    Rails.logger.stub(:info, ->(message) { logs << JSON.parse(message, symbolize_names: true) }) do
      assert_not harness.require_step_up!(scope: "settings_passkey")
    end

    event = logs.find { |entry| entry[:event] == "auth.step_up.required" }

    assert event, "expected auth.step_up.required diagnostic log"
    data = event.fetch(:data)

    assert_equal "VerificationBaseStepUpLoggingTest::Harness", data[:controller]
    assert_equal "update", data[:action]
    assert_equal "POST", data[:method]
    assert_equal "text/html", data[:format]
    assert_equal "app", data[:surface]
    assert_equal "client", data[:actor_type]
    assert_equal "settings_passkey", data[:scope]
    assert_equal StepUpRequirement::NO_AAL, data[:required_aal]
    assert_not data[:step_up_satisfied]
    assert data[:step_up_usable_token]
    assert_equal "passkey", data[:step_up_method]
    assert_equal "settings_passkey", data[:step_up_scope]
    assert_match(/\A\d{4}-\d{2}-\d{2}T/, data[:step_up_expires_at])

    serialized = event.to_json

    assert_not_includes serialized, token.public_id
    assert_not_includes serialized, token.last_step_up_session_public_id
  end
end
