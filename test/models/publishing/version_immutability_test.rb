# frozen_string_literal: true

require "test_helper"

module Publishing
  # Published history must survive careless maintenance code, so the guarantee
  # is tested through the paths that bypass Active Record callbacks entirely.
  class VersionImmutabilityTest < ActiveSupport::TestCase
    setup do
      @category = publishing_category_vocabulary(audience: "app", surface: "docs")
      @tag = publishing_tag_vocabulary(audience: "app", surface: "docs")
      entry = publishing_draft(audience: "app", surface: "docs", slug: "immutable-entry", title: "Immutable")
      assign_taxonomy(entry.current_revision)
      @version = PromoteRevisionOperation.call(revision: entry.current_revision)
      @version = Docs::App::EntryVersion.includes(
        :single_taxonomy_assignments, :multiple_taxonomy_assignments,
      ).find(@version.id)
    end

    test "active record refuses to update or destroy a version" do
      assert_raises(ActiveRecord::ReadOnlyRecord) { @version.update!(title: "changed") }
      assert_raises(ActiveRecord::ReadOnlyRecord) { @version.destroy! }
    end

    test "postgresql refuses an update that bypasses active record" do
      assert_database_rejects { @version.update_column(:title, "changed") }
      assert_database_rejects { Docs::App::EntryVersion.where(id: @version.id).update_all(title: "changed") }
    end

    test "postgresql refuses a delete that bypasses active record" do
      assert_database_rejects { Docs::App::EntryVersion.where(id: @version.id).delete_all }
      assert_database_rejects do
        PublishingRecord.lease_connection.execute("DELETE FROM publishing_entry_versions WHERE id = #{@version.id}")
      end
    end

    test "active record refuses to update or destroy a version taxonomy snapshot" do
      single = Docs::App::VersionSingleTaxonomyAssignment.find_by!(entry_version_id: @version.id)
      multiple = Docs::App::VersionMultipleTaxonomyAssignment.find_by!(entry_version_id: @version.id)

      assert_raises(ActiveRecord::ReadOnlyRecord) { single.update!(term_name_snapshot: "changed") }
      assert_raises(ActiveRecord::ReadOnlyRecord) { single.destroy! }
      assert_raises(ActiveRecord::ReadOnlyRecord) { multiple.update!(term_name_snapshot: "changed") }
      assert_raises(ActiveRecord::ReadOnlyRecord) { multiple.destroy! }
    end

    test "postgresql refuses raw writes to version taxonomy snapshots" do
      single = Docs::App::VersionSingleTaxonomyAssignment.find_by!(entry_version_id: @version.id)
      multiple = Docs::App::VersionMultipleTaxonomyAssignment.find_by!(entry_version_id: @version.id)
      connection = PublishingRecord.lease_connection

      assert_database_rejects do
        connection.execute(
          "UPDATE publishing_version_single_taxonomy_assignments SET term_name_snapshot = 'x' WHERE id = #{single.id}",
        )
      end
      assert_database_rejects do
        connection.execute("DELETE FROM publishing_version_single_taxonomy_assignments WHERE id = #{single.id}")
      end
      assert_database_rejects do
        connection.execute(
          "UPDATE publishing_version_multiple_taxonomy_assignments SET position_snapshot = 9 WHERE id = #{multiple.id}",
        )
      end
      assert_database_rejects do
        connection.execute("DELETE FROM publishing_version_multiple_taxonomy_assignments WHERE id = #{multiple.id}")
      end
    end

    test "draft assignments stay editable" do
      entry = publishing_draft(audience: "app", surface: "docs", slug: "editable-entry", title: "Editable")
      revision = entry.current_revision
      assign_taxonomy(revision)
      assignment = Docs::App::RevisionMultipleTaxonomyAssignment.find_by!(entry_revision_id: revision.id)

      assignment.update!(position: 5)

      assert_equal 5, assignment.reload.position
      assert_nothing_raised { assignment.destroy! }
    end

    private

    def assign_taxonomy(revision)
      guide = Docs::App::TaxonomyTerm.find_by(vocabulary: @category, locale: "ja", slug: "guide") ||
        publishing_term(vocabulary: @category, locale: "ja", slug: "guide")
      ruby = Docs::App::TaxonomyTerm.find_by(vocabulary: @tag, locale: "ja", slug: "ruby") ||
        publishing_term(vocabulary: @tag, locale: "ja", slug: "ruby")

      create_single_assignment(
        entry_revision: revision, vocabulary: @category, vocabulary_kind: @category.kind, taxonomy_term: guide,
        locale: "ja",
      )
      create_multiple_assignment(
        entry_revision: revision, vocabulary: @tag, vocabulary_kind: @tag.kind, taxonomy_term: ruby, locale: "ja",
        position: 0,
      )
    end
  end
end
