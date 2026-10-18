# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: jwt_occurrences
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
#  index_jwt_occurrences_on_body                 (body) UNIQUE
#  index_jwt_occurrences_on_body_and_created_at  (body,created_at)
#  index_jwt_occurrences_on_public_id            (public_id) UNIQUE
#  index_jwt_occurrences_on_purge_eligible_at            (purge_eligible_at)
#  index_jwt_occurrences_on_status_id            (status_id)
#
# Foreign Keys
#
#  fk_jwt_occurrences_on_status_id  (status_id => jwt_occurrence_statuses.id)
#

require "test_helper"

class JwtOccurrenceTest < ActiveSupport::TestCase
  test "defaults status_id to nothing" do
    record = build_occurrence(JwtOccurrence, body: "jwt-occur-1", public_id: "X" * 21)

    assert_equal JwtOccurrenceStatus::NOTHING, record.status_id
  end

  test "lifecycle timestamps default" do
    record = build_occurrence(JwtOccurrence, body: "jwt-occur-2", public_id: "Y" * 21)

    assert_occurrence_lifecycle_defaults(record)
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
