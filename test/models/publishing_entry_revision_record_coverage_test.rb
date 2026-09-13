# frozen_string_literal: true

require "test_helper"

class PublishingEntryRevisionRecordCoverageTest < ActiveSupport::TestCase
  test "promoted? and taxonomy assignment helpers cover the remaining concern lines" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "rev-cov", title: "Revision Cov")
    revision = entry.current_revision

    assert_not revision.promoted?
    assert_kind_of Array, revision.taxonomy_assignments
    assert_kind_of Array, revision.archived_taxonomy_assignments

    version = Publishing::PromoteRevisionOperation.call(revision: revision)

    assert_predicate version, :present?
    assert_predicate revision.reload, :promoted?
  end
end
