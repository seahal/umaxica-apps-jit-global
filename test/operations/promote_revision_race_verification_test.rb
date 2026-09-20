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

  # Only a collision on the idempotency index means another promotion won the
  # race; a duplicate sequence or public id is a genuine failure and must not be
  # swallowed as one.
  test "the idempotency index is the only uniqueness failure treated as a lost race" do
    Publishing::ContentFamilies::ENTRY_CLASSES.each do |entry_class|
      entry = entry_class.create!(locale: "en")
      revision = entry.revisions.create!(
        locale: "en", title: "Race", body: { "text" => "Race" },
        schema_version: 1, content_digest: Digest::SHA256.hexdigest("Race"), sequence: 1,
      )
      winner = Publishing::PromoteRevisionOperation.call(revision: revision)
      owner = revision.entry
      prefix = "uidx_#{entry_class::SURFACE}_#{entry_class::AUDIENCE}_ver"

      unique_index_names =
        owner.versions.klass.lease_connection
          .indexes(owner.versions.klass.table_name)
          .select(&:unique).map(&:name)
      revision_index = "#{prefix}_on_revision"

      assert_includes unique_index_names, revision_index
      other_indexes = unique_index_names - [revision_index]

      assert_not_empty other_indexes

      # A versions relation whose #create! always loses a chosen unique race and
      # whose lookups behave as if the winning row is already committed. The
      # operation reloads `owner` inside `with_lock`, which resets any relation
      # captured earlier, so the stub sits on the record itself.
      losing_versions =
        lambda do |index_name|
          fake = Object.new
          fake.define_singleton_method(:find_by) { |*| nil }
          fake.define_singleton_method(:find_by!) { |*| winner }
          fake.define_singleton_method(:maximum) { |*| 0 }
          fake.define_singleton_method(:create!) do |*|
            raise ActiveRecord::RecordNotUnique,
                  %(PG::UniqueViolation: ERROR: duplicate key value violates unique constraint "#{index_name}")
          end
          fake
        end

      # A collision on the revision idempotency index means another promotion won
      # the race: the loser re-reads and hands back the winner's version.
      owner.stub(:versions, losing_versions.call(revision_index)) do
        assert_equal winner, Publishing::PromoteRevisionOperation.call(revision: revision)
      end

      # A duplicate sequence, public id, or any other unique violation is a
      # genuine failure and must propagate unswallowed.
      other_indexes.each do |index_name|
        owner.stub(:versions, losing_versions.call(index_name)) do
          error =
            assert_raises(ActiveRecord::RecordNotUnique) do
              Publishing::PromoteRevisionOperation.call(revision: revision)
            end

          assert_match index_name, error.message
        end
      end

      assert_equal [winner.id], entry.versions.reload.pluck(:id)
    end
  end
end
