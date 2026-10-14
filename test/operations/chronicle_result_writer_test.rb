# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ChronicleResultWriterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @policy =
      ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |policy|
        policy.name = "Security"
        policy.duration_days = 365
        policy.permanent = false
      end
    occurred_at = Time.current
    @chronicle = Chronicle.create!(
      event_uuid: SecureRandom.uuid,
      action: "auth.sign_in.failed",
      result: "intent",
      metadata: {},
      changeset: {},
      occurred_at: occurred_at,
      erasable_at: ChronicleRecordPolicy.erasable_at_for(policy: @policy, occurred_at: occurred_at),
      chronicle_retention_policy: @policy,
    )
  end

  test "returns updated chronicle on success" do
    result = ChronicleResultWriter.call(
      chronicle: @chronicle,
      result: "succeeded",
      event_uuid: SecureRandom.uuid,
      request_id: "request-result-success",
      action: "auth.sign_in.failed",
    )

    assert_equal @chronicle, result
    assert_equal "succeeded", @chronicle.reload.result
  end

  test "logs fallback and reraises when result update fails" do
    fallback_called = false
    error = StandardError.new("update failed")

    @chronicle.stub(:update!, ->(*) { raise error }) do
      ChronicleFallbackRecorder.stub(:call, ->(*) { fallback_called = true }) do
        assert_raises(StandardError) do
          ChronicleResultWriter.call(
            chronicle: @chronicle,
            result: "succeeded",
            event_uuid: SecureRandom.uuid,
            request_id: "request-result-failure",
            action: "auth.sign_in.failed",
          )
        end
      end
    end

    assert fallback_called
  end
end
