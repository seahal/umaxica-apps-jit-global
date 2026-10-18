# typed: false
# frozen_string_literal: true

require "test_helper"

class OccurrenceTest < ActiveSupport::TestCase
  test "includes retainable defaults" do
    record = ClientOccurrence.new

    assert_occurrence_lifecycle_defaults(record)
  end

  test "accessible? and purgeable? reflect retainable state" do
    record = ClientOccurrence.new(discard_at: 1.hour.from_now, purge_eligible_at: 1.hour.ago)

    assert_predicate record, :accessible?
    assert_predicate record, :purgeable?
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
