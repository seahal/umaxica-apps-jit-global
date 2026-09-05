# typed: false
# frozen_string_literal: true

require "test_helper"

# Promotion is idempotent through a single unique index. When two promotions of
# the same revision race, the loser has to hand back the winner's version -- but
# only after proving that version really is this revision's complete snapshot.
# Handing back an incomplete or foreign version would publish an entry whose
# taxonomy does not match what was approved.
class PromoteRevisionRaceVerificationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def operation(revision)
    Publishing::PromoteRevisionOperation.new(revision: revision)
  end

  def revision_double(id:, single: 0, multiple: 0, media: 0)
    double = Object.new
    double.define_singleton_method(:id) { id }
    double.define_singleton_method(:single_taxonomy_assignments) { Struct.new(:count).new(single) }
    double.define_singleton_method(:multiple_taxonomy_assignments) { Struct.new(:count).new(multiple) }
    double.define_singleton_method(:media_usages) { Struct.new(:count).new(media) }
    double
  end

  def version_double(id:, revision_id:, single: 0, multiple: 0, media: 0)
    double = Object.new
    double.define_singleton_method(:id) { id }
    double.define_singleton_method(:entry_revision_id) { revision_id }
    double.define_singleton_method(:single_taxonomy_assignments) { Struct.new(:count).new(single) }
    double.define_singleton_method(:multiple_taxonomy_assignments) { Struct.new(:count).new(multiple) }
    double.define_singleton_method(:media_usages) { Struct.new(:count).new(media) }
    double
  end

  test "a version belonging to another revision is refused rather than handed back" do
    subject = operation(revision_double(id: 1))

    error =
      assert_raises(Publishing::PromoteRevisionOperation::RevisionMismatchError) do
        subject.send(:verify_complete!, version_double(id: 9, revision_id: 2))
      end

    assert_match(/version 9 does not belong to revision 1/, error.message)
  end

  test "a version missing taxonomy snapshots is refused with the counts on both sides" do
    subject = operation(revision_double(id: 1, single: 2, multiple: 3))

    error =
      assert_raises(Publishing::PromoteRevisionOperation::IncompleteVersionError) do
        subject.send(:verify_complete!, version_double(id: 9, revision_id: 1, single: 2, multiple: 1))
      end

    assert_match(%r{holds 2/1 taxonomy snapshots and 0 media usages, expected 2/3 and 0}, error.message)
  end

  test "a version that is this revision's complete snapshot is handed back" do
    subject = operation(revision_double(id: 1, single: 2, multiple: 3))
    version = version_double(id: 9, revision_id: 1, single: 2, multiple: 3)

    assert_equal version, subject.send(:verify_complete!, version)
  end

  # Only a collision on the idempotency index means another promotion won the
  # race; a duplicate sequence or public id is a genuine failure and must not be
  # swallowed as one.
  test "the idempotency index is the only uniqueness failure treated as a lost race" do
    assert_includes Publishing::PromoteRevisionOperation::IDEMPOTENCY_INDEX, "entry_revision_id"
    assert_not Publishing::PromoteRevisionOperation::IDEMPOTENCY_INDEX.include?("sequence")
    assert_not Publishing::PromoteRevisionOperation::IDEMPOTENCY_INDEX.include?("public_id")
  end
end
