# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ChronicleIntentWriterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @policy =
      ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |policy|
        policy.name = "Security"
        policy.duration_days = 365
        policy.permanent = false
      end
  end

  test "skips visibility contexts that resolve to blank" do
    fallback_called = false

    ChronicleFallbackRecorder.stub(:call, ->(*) { fallback_called = true }) do
      ChronicleIntentWriter.call(
        event_uuid: SecureRandom.uuid,
        action: "auth.sign_in.failed",
        visibility_contexts: ["unknown-context"],
      )
    end

    assert fallback_called
  end

  test "creates chronicle visibility for resolved context" do
    context = ChronicleVisibilityContext.create!(code: "audit", name: "Audit")

    chronicle = ChronicleIntentWriter.call(
      event_uuid: SecureRandom.uuid,
      action: "auth.sign_in.failed",
      visibility_contexts: ["audit"],
    )

    assert_equal [context.id], ChronicleVisibility.where(chronicle_id: chronicle.id)
      .pluck(:chronicle_visibility_context_id)
  end
end
