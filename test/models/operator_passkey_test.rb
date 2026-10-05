# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_passkeys
# Database name: org_zenith
#
#  id                       :bigint           not null, primary key
#  aaguid                   :uuid
#  authenticator_attachment :string
#  backup_eligible          :boolean
#  backup_state             :boolean
#  description              :string           default(""), not null
#  last_used_at             :datetime
#  metadata_source          :string
#  provider_name            :string
#  public_key               :text             not null
#  sign_count               :bigint           default(0), not null
#  transports               :jsonb
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  external_id              :uuid             not null
#  staff_id                 :bigint           not null
#  status_id                :bigint           default(1), not null
#  webauthn_id              :string           default(""), not null
#
# Indexes
#
#  index_operator_passkeys_on_external_id  (external_id)
#  index_operator_passkeys_on_staff_id     (staff_id)
#  index_operator_passkeys_on_status_id    (status_id)
#  index_operator_passkeys_on_webauthn_id  (webauthn_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (status_id => operator_passkey_statuses.id)
#

require "test_helper"

class OperatorPasskeyTest < ActiveSupport::TestCase
  test "retained terminal history does not consume the four Passkey slots" do
    actor = Operator.create!
    [OperatorPasskeyStatus::REVOKED].each do |terminal_status|
      historical = actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "history-public-key")
      historical.update!(status_id: terminal_status)
    end
    3.times { actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "slot-public-key") }

    assert_equal 3, actor.staff_passkeys.active.count
    actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "fourth-slot-public-key")

    assert_equal 4, actor.staff_passkeys.active.count
    assert_no_difference(-> { actor.staff_passkeys.count }) do
      assert_raises(ActiveRecord::RecordInvalid) do
        actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "overflow-public-key")
      end
    end

    assert_equal 5, actor.staff_passkeys.count
    assert_not StepUpBootstrapEligibilityQuery.call(actor: actor)
  end

  test "a stale loaded owner association cannot admit a fifth Passkey" do
    actor = Operator.create!
    stale_actor = Operator.find(actor.id)
    stale_actor.staff_passkeys.load
    4.times { actor.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "slot-public-key") }
    candidate = OperatorPasskey.new(
      staff: stale_actor, webauthn_id: SecureRandom.uuid, public_key: "overflow-public-key",
    )

    assert_not candidate.valid?
    assert_no_difference(-> { actor.staff_passkeys.count }) do
      assert_raises(ActiveRecord::RecordInvalid) { candidate.save! }
    end

    assert_equal 4, actor.staff_passkeys.active.count
  end

  test "should create passkey with valid attributes" do
    passkey = OperatorPasskey.new(
      staff: Operator.find_by!(public_id: "BCDE2345FGHJ67KM"),
      description: "Staff Passkey",
      public_key: "test_staff_public_key",
      sign_count: 1,
      external_id: SecureRandom.uuid,
      webauthn_id: SecureRandom.hex(32),
    )

    assert_equal "Staff Passkey", passkey.description
    assert_equal "test_staff_public_key", passkey.public_key
    assert_equal 1, passkey.sign_count
  end

  test "defaults status_id to active" do
    passkey = OperatorPasskey.new(
      staff: Operator.find_by!(public_id: "BCDE2345FGHJ67KM"),
      description: "Staff Passkey",
      public_key: "test_staff_public_key",
      sign_count: 1,
      external_id: SecureRandom.uuid,
      webauthn_id: SecureRandom.hex(32),
    )

    assert_equal OperatorPasskeyStatus::ACTIVE, passkey.status_id
  end

  test "status association uses status_id" do
    status = OperatorPasskeyStatus.find(OperatorPasskeyStatus::ACTIVE)
    passkey = OperatorPasskey.create!(
      staff: Operator.find_by!(public_id: "BCDE2345FGHJ67KM"),
      description: "Staff Passkey",
      public_key: "test_staff_public_key",
      sign_count: 1,
      external_id: SecureRandom.uuid,
      webauthn_id: SecureRandom.hex(32),
      status: status,
    )

    assert_equal status, passkey.reload.status
    assert_equal status.id, passkey.status_id
  end

  test "should belong to staff" do
    assert_respond_to OperatorPasskey.new, :staff
  end

  test "should have name field" do
    passkey = OperatorPasskey.new(description: "Example Name")

    assert_equal "Example Name", passkey.description
  end

  test "should have public_key field" do
    passkey = OperatorPasskey.new(public_key: "staff_key")

    assert_equal "staff_key", passkey.public_key
  end

  test "should inherit from OrgPrincipalRecord" do
    assert_operator OperatorPasskey, :<, OrgPrincipalRecord
  end

  test "should have required database columns" do
    required_columns = %w(description public_key sign_count external_id staff_id webauthn_id)

    required_columns.each do |column|
      assert_includes OperatorPasskey.column_names, column
    end
  end

  test "enforces maximum passkeys per staff" do
    staff = Operator.create!
    4.times { staff.staff_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "slot-public-key") }
    extra_passkey = OperatorPasskey.new(
      staff: staff,
      description: "Overflow Staff Key",
      public_key: "overflow-key",
      sign_count: 0,
      external_id: SecureRandom.uuid,
      webauthn_id: SecureRandom.hex(32),
    )

    assert_not extra_passkey.valid?
    assert_includes extra_passkey.errors[:base],
                    "exceeds maximum passkeys per staff (#{OperatorPasskey::MAX_PASSKEYS_PER_STAFF})"
  end
end
