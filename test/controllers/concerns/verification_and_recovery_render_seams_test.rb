# typed: false
# frozen_string_literal: true

require "test_helper"

# The page a surface answers a ceremony with is a surface decision, delegated to
# one overridable method per flow. The defaults render the controller's own
# template, and a passkey options request that fails for any reason answers with
# the shared options error rather than leaking the cause to the browser.
class VerificationAndRecoveryRenderSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness(concern, &definition)
    Class.new do
      include concern

      attr_reader :rendered, :errors_rendered

      def render(*args, **kwargs)
        @rendered = [args, kwargs]
      end

      def render_error(key, status)
        @errors_rendered = [key, status]
      end

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new
  end

  test "a passkey options request that fails answers with the shared options error" do
    flow =
      harness(PasskeySignInFlow) do
        def params = ActionController::Parameters.new(identifier: "someone@example.com")

        def valid_passkey_identifier?(_value) = true

        def find_active_passkey_actor(_identifier) = raise(IOError, "credential store unavailable")

        def passkey_identifier_invalid_error_key = "errors.webauthn.identifier_invalid"
      end

    recorded = []
    Rails.logger.stub(:error, ->(*args, &block) { recorded << (args.first || block&.call).to_s }) do
      flow.options
    end

    assert_equal ["errors.webauthn.options_failed", :unprocessable_content], flow.errors_rendered
    assert(recorded.any? { |line| line.include?("webauthn.authentication_options_failed") })
  end
end
