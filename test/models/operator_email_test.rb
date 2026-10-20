# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_emails
# Database name: org_principal
#
#  id                             :bigint           not null, primary key
#  address                        :string           not null
#  address_digest                 :string
#  locked_at                      :datetime
#  notifiable                     :boolean          default(TRUE), not null
#  otp_attempts_count             :integer          default(0), not null
#  otp_last_sent_at               :datetime
#  promotional                    :boolean          default(TRUE), not null
#  subscribable                   :boolean          default(TRUE), not null
#  undeletable                    :boolean          default(FALSE), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  public_id                      :string(21)       default(""), not null
#  staff_id                       :bigint           not null
#  staff_identity_email_status_id :bigint           default(6), not null
#
# Indexes
#
#  index_operator_emails_on_address_digest                  (address_digest) UNIQUE WHERE (address_digest IS NOT NULL)
#  index_operator_emails_on_public_id                       (public_id) UNIQUE
#  index_operator_emails_on_staff_id                        (staff_id)
#  index_operator_emails_on_staff_identity_email_status_id  (staff_identity_email_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (staff_identity_email_status_id => operator_email_statuses.id)
#

require "test_helper"

class OperatorEmailTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses, :operator_email_statuses

  setup do
    @staff = Operator.find_by!(public_id: "CDEF2345GHJK67NM")
    @valid_attributes = {
      address: "staff@example.com",
      confirm_policy: true,
      staff: @staff,
    }.freeze
  end

  # Basic model structure tests
  test "should inherit from AppPrincipalRecord" do
    assert_operator OperatorEmail, :<, OrgPrincipalRecord
  end

  test "should include Email concern" do
    assert_includes OperatorEmail.included_modules, Email
  end

  # Email concern validation tests
  test "should be valid with valid email and policy confirmation" do
    staff_email = OperatorEmail.new(@valid_attributes)

    assert_predicate staff_email, :valid?
  end

  test "should require valid email format" do
    staff_email = OperatorEmail.new(@valid_attributes.merge(address: "invalid-email"))

    assert_not staff_email.valid?
    assert_predicate staff_email.errors[:address], :any?
  end

  test "should require email presence" do
    staff_email = OperatorEmail.new(@valid_attributes.except(:address))

    assert_not staff_email.valid?
    assert_predicate staff_email.errors[:address], :any?
  end

  test "should require policy confirmation" do
    staff_email = OperatorEmail.new(@valid_attributes.merge(confirm_policy: false))

    assert_not staff_email.valid?
    assert_predicate staff_email.errors[:confirm_policy], :any?
  end

  test "should require unique email addresses" do
    OperatorEmail.create!(@valid_attributes)
    duplicate_email = OperatorEmail.new(@valid_attributes)

    assert_not duplicate_email.valid?
    assert_predicate duplicate_email.errors[:address], :any?
  end

  test "sets address digests from normalized input" do
    staff_email = OperatorEmail.create!(
      raw_address: "STAFF-BIDX@EXAMPLE.COM",
      confirm_policy: true,
      staff: @staff,
    )

    expected = IdentifierBlindIndex.bidx_for_email("staff-bidx@example.com", realm: :org)

    assert_equal expected, staff_email.address_digest
  end

  test "finds by normalized address digest" do
    staff_email = OperatorEmail.create!(
      raw_address: "staff-find@example.com",
      confirm_policy: true,
      staff: @staff,
    )

    assert_equal staff_email,
                 OperatorEmail.find_by(
                   address_digest: IdentifierBlindIndex.bidx_for_email("STAFF-FIND@example.com", realm: :org),
                 )
    assert_nil OperatorEmail.find_by(address_digest: IdentifierBlindIndex.bidx_for_email("not-an-email", realm: :org))
  end

  test "should downcase email address before saving" do
    staff_email = OperatorEmail.new(@valid_attributes.merge(address: "STAFF@EXAMPLE.COM"))
    staff_email.save!

    assert_equal "staff@example.com", staff_email.address
  end

  test "should assign numeric id before creation" do
    staff_email = OperatorEmail.new(@valid_attributes)

    assert_nil staff_email.id
    staff_email.save!

    assert_not_nil staff_email.id
    assert_kind_of Integer, staff_email.id
  end

  # Encryption tests
  test "should encrypt email address" do
    staff_email = OperatorEmail.create!(@valid_attributes)
    # The address should be encrypted in the database
    query = "SELECT address FROM #{OperatorEmail.table_name} WHERE id = '#{staff_email.id}'"
    raw_data = OperatorEmail.connection.execute(query).first
    assert_not_equal @valid_attributes[:address], raw_data["address"] if raw_data
  end

  test "assigns placeholder staff_id when missing" do
    staff_email = OperatorEmail.new(@valid_attributes.except(:staff))
    staff_email.valid?

    assert_equal 0, staff_email.staff_id
  end

  test "to_param uses public_id" do
    staff_email = OperatorEmail.create!(@valid_attributes)

    assert_equal staff_email.public_id, staff_email.to_param
  end

  test "blocks destroying an undeletable email" do
    staff_email = OperatorEmail.create!(@valid_attributes.merge(undeletable: true))

    assert_raises(ActiveRecord::RecordNotDestroyed) { staff_email.destroy! }
    assert_includes staff_email.errors[:base], "cannot delete a protected email address"
    assert_predicate staff_email.reload, :undeletable?
  end

  test "enforces maximum emails per staff" do
    staff = Operator.create!(staff_status: OperatorStatus.find(OperatorStatus::NOTHING))
    Prosopite.pause do
      OperatorEmail::MAX_EMAILS_PER_STAFF.times do |i|
        OperatorEmail.create!(
          address: "staff_limit#{i}@example.com",
          confirm_policy: true,
          staff: staff,
        )
      end
    end

    extra_email = OperatorEmail.new(
      address: "overflow_staff@example.com",
      confirm_policy: true,
      staff: staff,
    )

    assert_not extra_email.valid?
    assert_includes extra_email.errors[:base], "exceeds maximum emails per staff (#{OperatorEmail::MAX_EMAILS_PER_STAFF})"
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::OperatorEmail)
  end
end
