# typed: false
# frozen_string_literal: true

require "test_helper"

# Per-surface constants the shared flows read: which notice a completed
# verification shows, how a staff passkey identifier is normalised and
# validated, and what a social sign-up says when the stealth challenge fails.
# Each belongs to one surface, and reading another surface's value would show a
# client the wrong copy or accept an identifier this surface does not issue.
class Auth::SimpleSurfaceDelegationsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class, params: { ri: "jp" })
    Class.new(controller_class) do
      attr_accessor :params_hash, :rendered

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def render(*args, **kwargs)
        self.rendered = [args, kwargs]
      end

      def invoke(name, ...) = send(name, ...)
    end.new.tap do |harness|
      harness.params_hash = params
      harness.request = ActionDispatch::TestRequest.create
    end
  end

  test "each surface shows its own completed-verification notice" do
    com = harness_for(Auth::Com::VerificationsController).invoke(:verification_success_notice_key)
    org = harness_for(Auth::Org::VerificationsController).invoke(:verification_success_notice_key)

    assert_not_equal com, org
    assert_predicate I18n.t(com), :present?
    assert_predicate I18n.t(org), :present?
  end

  test "the staff passkey identifier is normalised and validated against the operator format" do
    harness = harness_for(
      Auth::Org::Sign::In::Emergency::Passkey::VerificationsController,
      params: { identifier: " ABCDEFGHIJKLMNOPQRSTU " },
    )

    normalized = harness.invoke(:normalized_passkey_identifier)

    assert_equal Operator.normalize_public_id(" ABCDEFGHIJKLMNOPQRSTU "), normalized
    assert_not harness.invoke(:valid_passkey_identifier?, "not a public id")
  end

  {
    "apple" => Auth::App::Sign::Up::Check::Apple::ConfirmationsController,
    "google" => Auth::App::Sign::Up::Check::Google::ConfirmationsController,
  }.each do |provider, controller_class|
    test "a failed stealth challenge on the #{provider} confirmation is refused and recorded" do
      harness = harness_for(controller_class)
      recorded = []

      Rails.logger.stub(:info, ->(*args, &block) { recorded << (args.first || block&.call).to_s }) do
        harness.invoke(:log_social_signup_turnstile_failure, { "success" => false })
      end

      harness.invoke(:render_turnstile_failure)

      assert_equal(
        [[], { plain: I18n.t("turnstile_error"), status: :unprocessable_content }],
        harness.rendered,
      )
      assert(recorded.any? { |line| line.include?("sign_up.social_confirmation.turnstile_failed") })
    end
  end
end
