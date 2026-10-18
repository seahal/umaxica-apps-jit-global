# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: telephone_occurrences
# Database name: occurrence
#
#  id           :bigint           not null, primary key
#  body         :string           default(""), not null
#  discard_at :datetime         default(Infinity), not null
#  memo         :string           default(""), not null
#  purge_eligible_at    :datetime         default(Infinity), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  public_id    :string(21)       default(""), not null
#  status_id    :bigint           default(0), not null
#
# Indexes
#
#  index_telephone_occurrences_on_body             (body) UNIQUE
#  index_telephone_occurrences_on_body_created_at  (body,created_at)
#  index_telephone_occurrences_on_public_id        (public_id) UNIQUE
#  index_telephone_occurrences_on_purge_eligible_at        (purge_eligible_at)
#  index_telephone_occurrences_on_status_id        (status_id)
#
# Foreign Keys
#
#  fk_telephone_occurrences_on_status_id  (status_id => telephone_occurrence_statuses.id)
#

require "test_helper"

class TelephoneOccurrenceTest < ActiveSupport::TestCase
  fixtures :telephone_occurrences, :telephone_occurrence_statuses

  test "defaults status_id to nothing" do
    record = TelephoneOccurrence.new(body: "+819011234567", public_id: "X" * 21)

    assert_equal TelephoneOccurrenceStatus::NOTHING, record.status_id
  end

  test "public_id length" do
    record = build_occurrence(TelephoneOccurrence, body: "+819012345678", public_id: "A" * 20)

    assert_invalid_attribute(record, :public_id)
  end

  test "public_id format" do
    record = build_occurrence(TelephoneOccurrence, body: "+819012345678", public_id: ("A" * 20) + "!")

    assert_invalid_attribute(record, :public_id)
  end

  test "public_id uniqueness" do
    existing = TelephoneOccurrence.find_by!(public_id: "one_tel_occ_id_000001")
    record = build_occurrence(TelephoneOccurrence, body: "+819011111111", public_id: existing.public_id)

    assert_invalid_attribute(record, :public_id)
  end

  test "body presence" do
    record = build_occurrence(TelephoneOccurrence, body: nil)

    assert_invalid_attribute(record, :body)
  end

  test "body uniqueness" do
    existing = TelephoneOccurrence.find_by!(public_id: "one_tel_occ_id_000001")
    record = build_occurrence(TelephoneOccurrence, body: existing.body)

    assert_invalid_attribute(record, :body)
  end

  test "status_id presence" do
    record = build_occurrence(TelephoneOccurrence, body: "+819012345678", status_id: nil)

    assert_invalid_attribute(record, :status_id)
  end

  test "memo length" do
    record = build_occurrence(TelephoneOccurrence, body: "+819012345678", memo: "a" * 1025)

    assert_invalid_attribute(record, :memo)
  end

  test "public_id auto generated on create" do
    record = build_occurrence(TelephoneOccurrence, body: "+819012345678", public_id: nil)

    assert_public_id_generated(record)
  end

  test "public_id preserved when provided" do
    custom_public_id = "Z" * 21
    record = build_occurrence(TelephoneOccurrence, body: "+819012345678", public_id: custom_public_id)

    assert_public_id_preserved(record, custom_public_id)
  end

  test "lifecycle timestamps default" do
    record = build_occurrence(TelephoneOccurrence, body: "+819012300000", public_id: "Y" * 21)

    assert_occurrence_lifecycle_defaults(record)
  end

  # E.164 normalization tests
  test "normalizes domestic Japanese number to E.164 in body field" do
    record = build_occurrence(TelephoneOccurrence, body: "090-1234-5678", public_id: "tel_norm_test_0000001")

    assert_predicate record, :valid?, "Record should be valid: #{record.errors.full_messages}"
    assert_equal "+819012345678", record.body
  end

  test "normalizes international prefix 00 to E.164 in body field" do
    record = build_occurrence(TelephoneOccurrence, body: "0081 90 1234 5678", public_id: "tel_norm_test_0000002")

    assert_predicate record, :valid?
    assert_equal "+819012345678", record.body
  end

  test "preserves already E.164 formatted body" do
    record = build_occurrence(TelephoneOccurrence, body: "+819012345678", public_id: "tel_norm_test_0000003")

    assert_predicate record, :valid?
    assert_equal "+819012345678", record.body
  end

  test "rejects body without leading 0 or + (ambiguous)" do
    record = build_occurrence(TelephoneOccurrence, body: "9012345678", public_id: "tel_norm_test_0000004")

    assert_not record.valid?
    assert_predicate record.errors[:body], :any?
  end

  test "rejects body with country code starting with 0" do
    record = build_occurrence(TelephoneOccurrence, body: "+0123456789", public_id: "tel_norm_test_0000005")

    assert_not record.valid?
    assert_predicate record.errors[:body], :any?
  end

  test "accepts maximum length E.164 body" do
    record = build_occurrence(TelephoneOccurrence, body: "+999999999999999", public_id: "tel_norm_test_0000006")

    assert_predicate record, :valid?
    assert_equal "+999999999999999", record.body
  end

  test "body uniqueness works with normalized values" do
    # Create first occurrence with normalized number
    TelephoneOccurrence.create!(
      body: "+819012345678",
      public_id: "tel_norm_unique_00001",
      status_id: TelephoneOccurrenceStatus::NOTHING,
    )

    # Try to create duplicate with different formatting
    duplicate = build_occurrence(TelephoneOccurrence, body: "090-1234-5678", public_id: "tel_norm_unique_00002")

    assert_not duplicate.valid?
    assert_predicate duplicate.errors[:body], :any?
  end

  test "preserves HMAC body without normalization" do
    hmac_body = "a" * 64
    record = build_occurrence(TelephoneOccurrence, body: hmac_body, public_id: "tel_hmac_test_0000001")

    assert_predicate record, :valid?
    assert_equal hmac_body, record.body
  end

  test "rejects invalid HMAC body format" do
    record = build_occurrence(TelephoneOccurrence, body: "invalid_hmac", public_id: "tel_hmac_test_0000002")

    assert_not record.valid?
    assert_predicate record.errors[:body], :any?
  end

  test "validates E.164 format for non-HMAC bodies" do
    record = build_occurrence(TelephoneOccurrence, body: "+0123456789", public_id: "tel_hmac_test_0000003")

    assert_not record.valid?
    assert_predicate record.errors[:body], :any?
  end
  private

  def build_occurrence(klass, attrs = {})
    klass.new(attrs)
  end

  def assert_invalid_attribute(record, attribute)
    assert_not_predicate record, :valid?, "expected #{record.class.name} to be invalid"
    assert_includes record.errors.attribute_names, attribute
  end

  def assert_public_id_generated(record)
    assert_predicate record, :valid?
    assert_predicate record.public_id, :present?
    assert_equal 21, record.public_id.length
  end

  def assert_public_id_preserved(record, expected_public_id)
    assert_predicate record, :valid?
    assert_equal expected_public_id, record.public_id
  end

  def assert_occurrence_lifecycle_defaults(record)
    assert_equal Float::INFINITY, record.discard_at
    assert_equal Float::INFINITY, record.purge_eligible_at
  end
end
