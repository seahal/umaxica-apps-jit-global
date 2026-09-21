# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: email_occurrences
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
#  index_email_occurrences_on_body             (body) UNIQUE
#  index_email_occurrences_on_body_created_at  (body,created_at)
#  index_email_occurrences_on_public_id        (public_id) UNIQUE
#  index_email_occurrences_on_purge_eligible_at        (purge_eligible_at)
#  index_email_occurrences_on_status_id        (status_id)
#
# Foreign Keys
#
#  fk_email_occurrences_on_status_id  (status_id => email_occurrence_statuses.id)
#

require "test_helper"

class EmailOccurrenceTest < ActiveSupport::TestCase
  fixtures :email_occurrences, :email_occurrence_statuses

  test "defaults status_id to nothing" do
    record = EmailOccurrence.new(body: "fresh@example.com", public_id: "X" * 21)

    assert_equal EmailOccurrenceStatus::NOTHING, record.status_id
  end

  test "public_id length" do
    record = build_occurrence(EmailOccurrence, body: "user@example.com", public_id: "A" * 20)

    assert_invalid_attribute(record, :public_id)
  end

  test "public_id format" do
    record = build_occurrence(EmailOccurrence, body: "user@example.com", public_id: ("A" * 20) + "!")

    assert_invalid_attribute(record, :public_id)
  end

  test "public_id uniqueness" do
    existing = build_occurrence(EmailOccurrence, body: "existing@example.com")
    existing.save!
    record = build_occurrence(EmailOccurrence, body: "unique@example.com", public_id: existing.public_id)

    assert_invalid_attribute(record, :public_id)
  end

  test "body presence" do
    record = build_occurrence(EmailOccurrence, body: nil)

    assert_invalid_attribute(record, :body)
  end

  test "body uniqueness" do
    existing = build_occurrence(EmailOccurrence, body: "existing@example.com")
    existing.save!
    record = build_occurrence(EmailOccurrence, body: existing.body)

    assert_invalid_attribute(record, :body)
  end

  test "status_id presence" do
    record = build_occurrence(EmailOccurrence, body: "user@example.com", status_id: nil)

    assert_invalid_attribute(record, :status_id)
  end

  test "memo length" do
    record = build_occurrence(EmailOccurrence, body: "user@example.com", memo: "a" * 1025)

    assert_invalid_attribute(record, :memo)
  end

  test "public_id auto generated on create" do
    record = build_occurrence(EmailOccurrence, body: "user@example.com", public_id: nil)

    assert_public_id_generated(record)
  end

  test "public_id preserved when provided" do
    custom_public_id = "Z" * 21
    record = build_occurrence(EmailOccurrence, body: "user@example.com", public_id: custom_public_id)

    assert_public_id_preserved(record, custom_public_id)
  end

  test "lifecycle timestamps default" do
    record = build_occurrence(EmailOccurrence, body: "expires@example.com", public_id: "Y" * 21)

    assert_occurrence_lifecycle_defaults(record)
  end

  # test "association deletion: destroys joining relations" do
  #   record = build_occurrence(EmailOccurrence, body: "joined@example.com")
  #   record.save!
  #   # Mocking a join - assuming AreaEmailOccurrence works
  #   join = AreaEmailOccurrence.create!(email_occurrence: record, area_occurrence: area_occurrences(:one))
  #
  #   record.destroy
  #   assert_raise(ActiveRecord::RecordNotFound) { join.reload }
  # end
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
