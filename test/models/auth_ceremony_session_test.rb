# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthCeremonySessionTest < ActiveSupport::TestCase
  CASES = [
    ClientAuthCeremonySession,
    VisitorAuthCeremonySession,
    OperatorAuthCeremonySession,
  ].freeze

  CASES.each do |model|
    test "#{model.name} issues digest-only sid and rotates without authority fields" do
      record, raw_sid = model.issue!

      assert_predicate record, :persisted?
      assert_equal 64, record.sid_digest.length
      assert_not_equal raw_sid, record.sid_digest
      assert_predicate record, :active?
      assert record.asserts_no_authority_api!

      found = model.find_active_by_raw_sid(raw_sid)

      assert_equal record.id, found.id

      rotated = record.rotate!

      assert_nil model.find_active_by_raw_sid(raw_sid)
      assert_equal record.id, model.find_active_by_raw_sid(rotated).id

      record.revoke!

      assert_not record.reload.active?
      assert_nil model.find_active_by_raw_sid(rotated)
    end
  end
end
