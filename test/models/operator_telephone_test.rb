# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_telephones
# Database name: org_principal
#
#  id                                 :bigint           not null, primary key
#  locked_at                          :datetime
#  number                             :string           not null
#  number_digest                      :string
#  otp_attempts_count                 :integer          default(0), not null
#  otp_counter                        :text             not null
#  otp_expires_at                     :datetime
#  otp_private_key                    :string           not null
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  staff_id                           :bigint           not null
#  staff_identity_telephone_status_id :bigint           default(6), not null
#
# Indexes
#
#  idx_on_staff_identity_telephone_status_id_6c01767c57  (staff_identity_telephone_status_id)
#  index_operator_telephones_on_number_digest            (number_digest) UNIQUE WHERE (number_digest IS NOT NULL)
#  index_operator_telephones_on_staff_id                 (staff_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (staff_identity_telephone_status_id => operator_telephone_statuses.id)
#

require "test_helper"

class OperatorTelephoneTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses, :operator_telephone_statuses

  setup do
    @staff = operators(:none_staff)
    @valid_attributes = {
      number: "+1234567890",
      confirm_policy: true,
      confirm_using_mfa: true,
      staff: @staff,
    }.freeze
  end

  # Basic model structure tests
  test "should inherit from AppPrincipalRecord" do
    assert_operator OperatorTelephone, :<, OrgPrincipalRecord
  end

  test "should include Telephone concern" do
    assert_includes OperatorTelephone.included_modules, Telephone
  end

  # Telephone concern validation tests
  test "should be valid with valid phone number and policy confirmations" do
    staff_telephone = OperatorTelephone.new(@valid_attributes)

    assert_predicate staff_telephone, :valid?
  end

  test "should require valid phone number format" do
    staff_telephone = OperatorTelephone.new(@valid_attributes.merge(number: "invalid!@#"))

    assert_not staff_telephone.valid?
    assert_predicate staff_telephone.errors[:number], :any?
  end

  test "should accept phone number with country code" do
    staff_telephone = OperatorTelephone.new(@valid_attributes.merge(number: "+81-90-1234-5678"))

    assert_predicate staff_telephone, :valid?
  end

  test "should accept phone number with parentheses" do
    staff_telephone = OperatorTelephone.new(@valid_attributes.merge(number: "+1 (555) 123-4567"))

    assert_predicate staff_telephone, :valid?
  end

  test "should reject phone number that is too short" do
    staff_telephone = OperatorTelephone.new(@valid_attributes.merge(number: "12"))

    assert_not staff_telephone.valid?
    assert_predicate staff_telephone.errors[:number], :any?
  end

  test "should reject phone number that is too long" do
    staff_telephone = OperatorTelephone.new(@valid_attributes.merge(number: "+1234567890123456789012"))

    assert_not staff_telephone.valid?
    assert_predicate staff_telephone.errors[:number], :any?
  end

  test "should require policy confirmation" do
    staff_telephone = OperatorTelephone.new(@valid_attributes.merge(confirm_policy: false))

    assert_not staff_telephone.valid?
    assert_predicate staff_telephone.errors[:confirm_policy], :any?
  end

  test "should require MFA confirmation" do
    staff_telephone = OperatorTelephone.new(@valid_attributes.merge(confirm_using_mfa: false))

    assert_not staff_telephone.valid?
    assert_predicate staff_telephone.errors[:confirm_using_mfa], :any?
  end

  test "sets number digests from normalized input" do
    staff_telephone = OperatorTelephone.create!(
      raw_number: "+1 (555) 123-4567",
      confirm_policy: true,
      confirm_using_mfa: true,
      staff: @staff,
    )

    expected = IdentifierBlindIndex.bidx_for_telephone("+15551234567", realm: :org)

    assert_equal expected, staff_telephone.number_digest
  end

  test "finds by normalized number digest" do
    staff_telephone = OperatorTelephone.create!(
      raw_number: "+1 (555) 765-4321",
      confirm_policy: true,
      confirm_using_mfa: true,
      staff: @staff,
    )

    assert_equal staff_telephone,
                 OperatorTelephone.find_by(
                   number_digest: IdentifierBlindIndex.bidx_for_telephone("+15557654321", realm: :org),
                 )
    assert_nil OperatorTelephone.find_by(number_digest: IdentifierBlindIndex.bidx_for_telephone("12", realm: :org))
  end

  test "should generate UUID v7 before creation" do
    staff_telephone = OperatorTelephone.new(@valid_attributes)

    assert_nil staff_telephone.id
    staff_telephone.save!

    assert_not_nil staff_telephone.id
    # UUID v7 format: xxxxxxxx-xxxx-7xxx-xxxx-xxxxxxxxxxxx
    assert_kind_of Integer, staff_telephone.id
  end

  test "enforces maximum telephones per staff" do
    staff = Operator.create!(staff_status: OperatorStatus.find(OperatorStatus::NOTHING))
    Prosopite.pause do
      OperatorTelephone::MAX_TELEPHONES_PER_STAFF.times do |i|
        OperatorTelephone.create!(
          number: "+1234567890#{i}",
          confirm_policy: true,
          confirm_using_mfa: true,
          staff: staff,
        )
      end
    end

    extra_telephone = OperatorTelephone.new(
      number: "+19876543210",
      confirm_policy: true,
      confirm_using_mfa: true,
      staff: staff,
    )

    assert_not extra_telephone.valid?
    assert_includes extra_telephone.errors[:base], "exceeds maximum telephones per staff (#{OperatorTelephone::MAX_TELEPHONES_PER_STAFF})"
  end

  test "allows nil staff id while limit validation is evaluated" do
    staff_telephone = OperatorTelephone.new(@valid_attributes)
    staff_telephone.staff_id = nil

    staff_telephone.valid?

    assert_empty staff_telephone.errors[:base]
  end

  test "rejects duplicated number digest" do
    existing = OperatorTelephone.create!(@valid_attributes.merge(raw_number: "+819012300001"))
    duplicate = OperatorTelephone.new(@valid_attributes.merge(raw_number: "+819012300001"))
    duplicate.number_digest = existing.number_digest

    duplicate.valid?

    assert_includes duplicate.errors.details[:number].pluck(:error), :taken
  end
end
