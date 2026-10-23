# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operators
# Database name: org_zenith
#
#  id                          :bigint           not null, primary key
#  access_state                :string           default("enabled"), not null
#  admin_locked_at             :datetime
#  admin_locked_reason_code    :string
#  admin_locked_reason_note    :text
#  birthdate                   :text
#  deactivated_at              :datetime
#  discard_at                :datetime         default(Infinity), not null
#  lock_version                :integer          default(0), not null
#  purge_eligible_at                   :datetime         default(Infinity), not null
#  reactivated_at              :datetime
#  token_valid_after_at        :datetime
#  webauthn_user_handle        :string           not null
#  withdrawal_started_at       :datetime
#  withdrawn_at                :datetime
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  admin_locked_by_operator_id :bigint
#  security_mode_id            :bigint           not null
#  mfa_status_id               :bigint           default(5), not null
#  public_id                   :string(16)       not null
#  status_id                   :bigint           default(2), not null
#  visibility_id               :bigint           default(2), not null
#
# Indexes
#
#  index_operators_on_access_state           (access_state)
#  index_operators_on_admin_locked_at        (admin_locked_at) WHERE (admin_locked_at IS NOT NULL)
#  index_operators_on_deactivated_at         (deactivated_at) WHERE (deactivated_at IS NOT NULL)
#  index_operators_on_discard_at           (discard_at)
#  index_operators_on_security_mode_id       (security_mode_id)
#  index_operators_on_mfa_status_id          (mfa_status_id)
#  index_operators_on_public_id              (public_id) UNIQUE
#  index_operators_on_purge_eligible_at              (purge_eligible_at)
#  index_operators_on_status_id              (status_id)
#  index_operators_on_token_valid_after_at   (token_valid_after_at) WHERE (token_valid_after_at IS NOT NULL)
#  index_operators_on_visibility_id          (visibility_id)
#  index_operators_on_webauthn_user_handle   (webauthn_user_handle) UNIQUE
#  index_operators_on_withdrawal_started_at  (withdrawal_started_at) WHERE (withdrawal_started_at IS NOT NULL)
#  index_operators_on_withdrawn_at           (withdrawn_at) WHERE (withdrawn_at IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (security_mode_id => operator_security_modes.id)
#  fk_rails_...  (mfa_status_id => operator_mfa_statuses.id)
#  fk_rails_...  (status_id => operator_statuses.id)
#  fk_rails_...  (visibility_id => operator_visibilities.id)
#

require "test_helper"

class OperatorTest < ActiveSupport::TestCase
  NIL_UUID = "00000000-0000-0000-0000-000000000000"
  VALID_PUBLIC_ID = "ABCDEFGH2345WXYZ"
  SECOND_VALID_PUBLIC_ID = "BCDEFGHJ2345WXYZ"

  test "operator uses conventional table name" do
    assert_equal "operators", Operator.table_name
  end

  def setup
    Prosopite.pause do
      [0, 1, 2, 3].each { |id| OperatorVisibility.find_or_create_by!(id: id) }
      OperatorTelephoneStatus.find_or_create_by!(id: OperatorTelephoneStatus::UNVERIFIED)
      OperatorEmailStatus.find_or_create_by!(id: OperatorEmailStatus::UNVERIFIED)
      OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    end
  end

  # ==========================================================================
  # A. Normal cases (specification compliance)
  # ==========================================================================

  test "public_id is auto-generated when not specified" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_predicate staff.public_id, :present?
  end

  test "auto-generated public_id is exactly 16 characters" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_equal 16, staff.public_id.length
  end

  test "default visibility_id is staff (2)" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_equal OperatorVisibility::STAFF, staff.visibility_id
  end

  test "login_allowed? is false for reserved status" do
    staff = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      public_id: Operator.generate_public_id, status_id: OperatorStatus::RESERVED,
    )

    assert_not staff.login_allowed?
  end

  test "login_allowed? remains true for nothing status while active" do
    staff = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      public_id: Operator.generate_public_id, status_id: OperatorStatus::NOTHING,
    )

    assert_predicate staff, :login_allowed?
  end

  test "withdrawal completion cannot precede withdrawal start" do
    staff = Operator.new(
      security_mode_id: SecurityModeConfigurable::ADVANCED, withdrawal_started_at: Time.current,
      withdrawn_at: 1.minute.ago,
    )

    assert_not staff.valid?
    assert_not_empty staff.errors[:withdrawn_at]
  end

  test "visibility association resolves to OperatorVisibility with id 2 by default" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_equal OperatorVisibility::STAFF, staff.visibility.id
  end

  test "invalid visibility_id is rejected by foreign key" do
    staff = Operator.new(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      public_id: Operator.generate_public_id,
      status_id: OperatorStatus::NOTHING,
      visibility_id: 9_999,
    )
    assert_raises(ActiveRecord::InvalidForeignKey) do
      staff.save!(validate: false)
    end
  end

  test "auto-generated public_id is uppercase" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_equal staff.public_id, staff.public_id.upcase
  end

  test "auto-generated public_id contains only base32 characters" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_match(/\A[0-9A-FGHJKMNPQRSTVWXYZ]{16}\z/, staff.public_id)
  end

  test "auto-generated public_id is unique across multiple records" do
    public_ids = Prosopite.pause { 10.times.map { Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED).public_id } }

    assert_equal public_ids.uniq.size, public_ids.size
  end

  # ==========================================================================
  # B. Normalization (input equivalence)
  # Tests verify that various input formats are normalized to the same output.
  # This ensures case-insensitivity and tolerance for common formatting.
  # ==========================================================================

  test "normalization: lowercase input is converted to uppercase" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "abcdefgh2345wxyz")
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "normalization: uppercase input remains uppercase" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: VALID_PUBLIC_ID)
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "normalization: mixed case input is converted to uppercase" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "AbCdEfGh2345WxYz")
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "normalization: hyphens are removed before validation" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "ABCD-EFGH-2345-WXYZ")
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "normalization: underscores are removed before validation" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "ABCD_EFGH_2345_WXYZ")
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "normalization: leading/trailing whitespace is stripped" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "  abcd-efgh-2345-wxyz  ")
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "normalization: multiple hyphens and underscores are all removed" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "ab-cd_efgh-23_45wxyz")
    staff.validate

    assert_equal VALID_PUBLIC_ID, staff.public_id
  end

  test "save normalizes public_id to uppercase" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "abcd-efgh-2345-wxyz")

    staff.update!(public_id: "bcde-fghj-2345-wxyz")

    assert_equal SECOND_VALID_PUBLIC_ID, staff.reload.public_id
  end

  # ==========================================================================
  # C. Boundary Value Analysis
  # ==========================================================================

  test "boundary: length 15 is invalid" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "ABCDEFGH2345WXY")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "boundary: length 16 is valid" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: VALID_PUBLIC_ID)

    assert_predicate staff, :valid?
  end

  test "boundary: length 17 is invalid" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "ABCDEFGH2345WXYZ2")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  # ==========================================================================
  # D. Equivalence Partitioning
  # ==========================================================================

  test "equivalence: secure random base32 alphabet input is valid" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "01ABCDGHJKMNPQRS")

    assert_predicate staff, :valid?
  end

  test "equivalence: invalid set - contains disallowed letter I" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "I1ABCDGHJKMNPQRS")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - contains disallowed letter L" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "L1ABCDGHJKMNPQRS")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - contains disallowed letter O" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "O1ABCDGHJKMNPQRS")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - contains disallowed letter U" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "U1ABCDGHJKMNPQRS")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - contains punctuation" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "ABCD!FGH2345WXYZ")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - contains non-ascii" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "ABCDあFGH2345WXYZ")

    assert_not staff.valid?
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - valid characters but wrong length" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "ABCDE")

    assert_not staff.valid?
  end

  test "equivalence: invalid set - nil input is rejected when explicitly provided" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: nil)

    assert_not staff.valid?
    assert_nil staff.public_id
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - empty string input is rejected" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "")

    assert_not staff.valid?
    assert_equal "", staff.public_id
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - whitespace only input is rejected" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "   ")

    assert_not staff.valid?
    assert_equal "", staff.public_id
    assert_not_empty staff.errors[:public_id]
  end

  test "equivalence: invalid set - separators only input is rejected" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "--__--")

    assert_not staff.valid?
    assert_equal "", staff.public_id
    assert_not_empty staff.errors[:public_id]
  end

  # ==========================================================================
  # E. Negative testing (failure modes)
  # ==========================================================================

  test "negative: public_id with lowercase letters normalizes and remains valid" do
    staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED, public_id: "abcdefgh2345wxy2")

    assert_predicate staff, :valid?
    assert_equal "ABCDEFGH2345WXY2", staff.public_id
  end

  test "negative: duplicate public_id is invalid (uniqueness)" do
    existing_staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    duplicate_staff = Operator.new(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      public_id: existing_staff.public_id,
    )

    assert_not duplicate_staff.valid?
    assert_not_empty duplicate_staff.errors[:public_id]
  end

  test "negative: public_id presence validation is configured" do
    # Verify that the presence validation is configured on the model
    validators = Operator.validators_on(:public_id)
    presence_validator = validators.find { |v| v.is_a?(ActiveRecord::Validations::PresenceValidator) }

    assert_not_nil presence_validator
  end

  # ==========================================================================
  # F. Test determinism - collision retry test
  # ==========================================================================

  test "determinism: collision retry generates different public_id on second attempt" do
    # Create an existing staff first
    existing_staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    existing_public_id = existing_staff.public_id

    call_count = 0
    Operator.stub(
      :exists?, ->(conditions) {
                  call_count += 1
                  # First call: simulate collision (return true)
                  # Second call and onwards: no collision (return false)
                  call_count == 1 && conditions[:public_id] == existing_public_id
                },
    ) do
      new_staff = Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED)
      # Stub generate_public_id to return existing_public_id first, then a different one
      generated_ids = [existing_public_id, SECOND_VALID_PUBLIC_ID]
      new_staff.stub(:generate_public_id, -> { generated_ids.shift || VALID_PUBLIC_ID }) do
        new_staff.valid?

        assert_equal SECOND_VALID_PUBLIC_ID, new_staff.public_id
      end
    end
  end

  test "determinism: auto-generated public_id does not collide with existing records" do
    # Create multiple staffs and ensure no collision
    Prosopite.pause { 10.times { Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED) } }

    public_ids = Operator.pluck(:public_id)

    assert_equal public_ids.uniq.size, public_ids.size
  end

  # ==========================================================================
  # Existing tests (refactored)
  # ==========================================================================

  test "should be valid with auto-generated public_id" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_predicate staff, :valid?
  end

  test "should have timestamps" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_not_nil staff.created_at
    assert_not_nil staff.updated_at
  end

  test "should have many telephones association" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_equal "staff_id", staff.class.reflect_on_association(:staff_telephones).foreign_key
  end

  test "dependent behaviors for staff associations" do
    assert_equal :restrict_with_error,
                 Operator.reflect_on_association(:staff_emails).options[:dependent]
    assert_equal :restrict_with_error,
                 Operator.reflect_on_association(:staff_telephones).options[:dependent]
    # Cross-database (chronicle DB) audit history: intentionally NO dependent:
    # cascade. Audit records outlive actor purge. See
    # adr/chronicle-audit-db-consolidation.md.
    assert_nil Operator.reflect_on_association(:staff_chronicles).options[:dependent]
    assert_nil Operator.reflect_on_association(:client_chronicles).options[:dependent]
    assert_equal :destroy,
                 Operator.reflect_on_association(:staff_secret_credentials).options[:dependent]
    assert_equal :destroy,
                 Operator.reflect_on_association(:staff_tokens).options[:dependent]
    # Cross-database (org_signal DB): NO implicit cascade; purged explicitly
    # via RetentionCrossDatabaseChildPurge from the operator purge path.
    assert_nil Operator.reflect_on_association(:notification_records).options[:dependent]
  end

  test "operator? should return true" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_predicate operator, :operator?
  end

  test "user? should return false" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_not staff.user?
  end

  test "should set default status before creation" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_equal OperatorStatus::NOTHING, staff.status_id
  end

  test "association deletion: restriction by dependent emails" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    OperatorEmail.create!(staff: staff, address: "staff_test@example.com")
    assert_no_difference("Operator.count") do
      assert_not staff.destroy
      assert_not_empty staff.errors[:base]
    end
  end

  test "association deletion: restriction by dependent telephones" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    OperatorTelephone.create!(staff: staff, number: "+15559876543")
    assert_no_difference("Operator.count") do
      assert_not staff.destroy
      assert_not_empty staff.errors[:base]
    end
  end

  test "association deletion: destroys dependent operator_tokens" do
    staff = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      id: 1_000_000_000_000 + SecureRandom.random_number(1_000_000_000),
    )
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: staff,
      discard_at: 1.day.from_now,
    )
    staff = StrictLoadingAssociationPreloader.for_destruction(staff.reload)
    staff.destroy
    assert_raise(ActiveRecord::RecordNotFound) { token.reload }
  end

  test "purge_eligible_at query excludes operators with default purge_eligible_at" do
    staff = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)

    assert_not_includes Operator.where(purge_eligible_at: ..Time.current), staff
  end

  test "purge_eligible_at query includes operators with past purge_eligible_at" do
    staff = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED, discard_at: 2.days.ago,
      purge_eligible_at: 1.day.ago,
    )

    assert_includes Operator.where(purge_eligible_at: ..Time.current), staff
  end
end
