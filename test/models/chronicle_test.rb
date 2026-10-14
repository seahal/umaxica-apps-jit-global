# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: chronicles
# Database name: chronicle
#
#  id                            :bigint           not null, primary key
#  action                        :string           not null
#  actor_type                    :string
#  changeset                     :jsonb            not null
#  erasable_at                   :datetime
#  event_uuid                    :string           not null
#  ip_address                    :inet
#  metadata                      :jsonb            not null
#  occurred_at                   :datetime         not null
#  reason                        :string
#  result                        :string           not null
#  subject_type                  :string
#  user_agent                    :text
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  actor_id                      :bigint
#  chronicle_retention_policy_id :bigint           not null
#  request_id                    :string
#  subject_id                    :bigint
#
# Indexes
#
#  index_chronicles_on_action                         (action)
#  index_chronicles_on_actor                          (actor_type,actor_id)
#  index_chronicles_on_chronicle_retention_policy_id  (chronicle_retention_policy_id)
#  index_chronicles_on_erasable_at                    (erasable_at)
#  index_chronicles_on_event_uuid                     (event_uuid) UNIQUE
#  index_chronicles_on_occurred_at                    (occurred_at)
#  index_chronicles_on_request_id                     (request_id)
#  index_chronicles_on_result                         (result)
#  index_chronicles_on_subject                        (subject_type,subject_id)
#
# Foreign Keys
#
#  fk_rails_...  (chronicle_retention_policy_id => chronicle_retention_policies.id)
#
require "test_helper"

class ChronicleTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "permanent policy rejects erasable_at" do
    policy = ChronicleRetentionPolicy.create!(
      code: "permanent",
      name: "Permanent",
      duration_days: 0,
      permanent: true,
    )

    chronicle = Chronicle.new(
      event_uuid: SecureRandom.uuid,
      chronicle_retention_policy: policy,
      action: "audit.export.created",
      result: "intent",
      occurred_at: Time.current,
      erasable_at: 1.year.from_now,
    )

    assert_not chronicle.valid?
    assert_includes chronicle.errors[:erasable_at], "must be nil for permanent retention"
  end

  test "non-permanent policy requires erasable_at" do
    policy =
      ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |record|
        record.name = "Security"
        record.duration_days = 365
        record.permanent = false
      end

    chronicle = Chronicle.new(
      event_uuid: SecureRandom.uuid,
      chronicle_retention_policy: policy,
      action: "auth.sign_in.failed",
      result: "intent",
      occurred_at: Time.current,
    )

    assert_not chronicle.valid?
    assert_includes chronicle.errors[:erasable_at], "must be present for non-permanent retention"
  end

  test "rejects metadata exceeding max json bytes" do
    policy = ChronicleRetentionPolicy.create!(
      code: "oversize",
      name: "Oversize",
      duration_days: 30,
      permanent: false,
    )

    chronicle = Chronicle.new(
      event_uuid: SecureRandom.uuid,
      chronicle_retention_policy: policy,
      action: "test.oversized",
      result: "intent",
      occurred_at: Time.current,
      erasable_at: 30.days.from_now,
      metadata: (0..5000).index_by { |i| i.to_s },
    )

    assert_not chronicle.valid?
    assert_includes chronicle.errors[:metadata], "is too large"
  end

  test "sanitizes forbidden metadata and changeset keys recursively" do
    policy =
      ChronicleRetentionPolicy.find_or_create_by!(code: "security") do |record|
        record.name = "Security"
        record.duration_days = 365
        record.permanent = false
      end

    chronicle = Chronicle.create!(
      event_uuid: SecureRandom.uuid,
      chronicle_retention_policy: policy,
      actor: policy,
      subject: policy,
      action: "auth.sign_in.failed",
      result: "intent",
      occurred_at: Time.current,
      erasable_at: 365.days.from_now,
      metadata: {
        password: "secret_credential",
        session_id_digest: "digest-ok",
        password_digest: "password-digest",
        token_digest: "token-digest",
        nested: { otp: "123456", reason: "bad-password" },
        list: [{ token: "raw-token", safe: "value" }],
      },
      changeset: {
        recovery_code: "raw-code",
        status: "locked",
      },
    )

    assert_nil chronicle.metadata["password"]
    assert_equal "digest-ok", chronicle.metadata["session_id_digest"]
    assert_nil chronicle.metadata["password_digest"]
    assert_nil chronicle.metadata["token_digest"]
    assert_nil chronicle.metadata.dig("nested", "otp")
    assert_equal "bad-password", chronicle.metadata.dig("nested", "reason")
    assert_nil chronicle.metadata.dig("list", 0, "token")
    assert_equal "value", chronicle.metadata.dig("list", 0, "safe")
    assert_nil chronicle.changeset["recovery_code"]
    assert_equal "locked", chronicle.changeset["status"]
  end
end
