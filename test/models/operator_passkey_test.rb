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
#  index_operator_passkeys_on_external_id_unique (external_id) UNIQUE
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
  test "physical deletion removes the Passkey from the owner count" do
    actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    passkeys =
      3.times.map do |index|
        PasskeyRegistrationOperation.call!(
          actor: actor, passkey_class: OperatorPasskey,
          attributes: { webauthn_id: SecureRandom.uuid, public_key: "slot-public-key-#{index}" },
        )
      end
    passkeys.first.destroy!
    replacement = PasskeyRegistrationOperation.call!(
      actor: actor, passkey_class: OperatorPasskey,
      attributes: { webauthn_id: SecureRandom.uuid, public_key: "replacement-public-key" },
    )

    assert_predicate replacement, :persisted?
    assert_equal 3, actor.staff_passkeys.count
    assert_not StepUpBootstrapEligibilityQuery.call(actor: actor)
  end

  test "validation accepts the tenth Passkey and refuses the eleventh for one staff" do
    owner = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    9.times do |index|
      PasskeyRegistrationOperation.call!(
        actor: owner, passkey_class: OperatorPasskey,
        attributes: { webauthn_id: SecureRandom.uuid, public_key: "limit-public-key-#{index}" },
      )
    end
    tenth = OperatorPasskey.new(staff: owner, webauthn_id: SecureRandom.uuid, public_key: "tenth-public-key")

    assert_predicate tenth, :valid?

    tenth.save!
    eleventh = OperatorPasskey.new(staff: owner, webauthn_id: SecureRandom.uuid, public_key: "eleventh-public-key")

    assert_not eleventh.valid?
    assert_match(/exceeds maximum passkeys/, eleventh.errors[:base].join)
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
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    OperatorPasskey::MAX_PASSKEYS_PER_STAFF.times do |i|
      PasskeyRegistrationOperation.call!(
        actor: staff, passkey_class: OperatorPasskey,
        attributes: { webauthn_id: SecureRandom.uuid, public_key: "slot-public-key-#{i}" },
      )
    end
    error =
      assert_raises(ActiveRecord::RecordInvalid) do
        PasskeyRegistrationOperation.call!(
          actor: staff, passkey_class: OperatorPasskey,
          attributes: { webauthn_id: SecureRandom.uuid, public_key: "overflow-key" },
        )
      end
    assert_match(/exceeds maximum passkeys/, error.record.errors[:base].join)
  end
end
