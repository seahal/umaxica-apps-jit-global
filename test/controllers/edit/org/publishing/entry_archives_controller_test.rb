# frozen_string_literal: true

require "test_helper"

class Edit::Org::Publishing::EntryArchivesControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_EDIT_STAFF_URL", "edit.org.localhost")
    host! @host
    @staff = operators(:one)
    @staff_headers = as_staff_headers(@staff, host: @host)
  end

  test "archiving records the timestamp, the reason, and the operator" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "archive-me", title: "Archive Me")

    post edit_org_publishing_docs_app_entry_archive_path(entry.public_id),
         params: { archive: { reason: "duplicate of the migration guide" } },
         headers: @staff_headers

    assert_response :see_other
    entry.reload

    assert_predicate entry, :archived?
    assert_equal "duplicate of the migration guide", entry.archive_reason
    assert_equal @staff.public_id, entry.archived_by_operator_public_id
  end

  test "archiving without a reason is refused because the row cannot hold one" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "no-archive-reason", title: "No Reason")

    post edit_org_publishing_docs_app_entry_archive_path(entry.public_id), headers: @staff_headers

    assert_response :unprocessable_content
    assert_equal "edit/org/publishing/docs/app/entries/show", inertia_component
    assert_equal "can't be blank", inertia_props.fetch("errors").fetch("reason")
    assert_not entry.reload.archived?
  end

  # Archiving a published entry would drop its public URL while an active publication row still
  # claims it is published. The operator ends the publication first, which is the order a reader
  # sees.
  test "a published entry cannot be archived until its publication ends" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "still-live", title: "Still Live")
    publishing_publish(entry: entry)

    post edit_org_publishing_docs_app_entry_archive_path(entry.public_id),
         params: { archive: { reason: "retired" } },
         headers: @staff_headers

    assert_response :unprocessable_content
    assert_equal(
      "a published entry cannot be archived; end its publication first",
      inertia_props.fetch("errors").fetch("base"),
    )
    assert_not entry.reload.archived?

    publication = entry.active_publication

    delete edit_org_publishing_docs_app_entry_publication_path(entry.public_id, publication.public_id),
           params: { publication: { reason: "retired" } },
           headers: @staff_headers

    assert_response :see_other

    post edit_org_publishing_docs_app_entry_archive_path(entry.public_id),
         params: { archive: { reason: "retired" } },
         headers: @staff_headers

    assert_response :see_other
    assert_predicate entry.reload, :archived?
  end

  test "an archived entry cannot be archived a second time" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "twice-archived", title: "Twice")

    post edit_org_publishing_docs_app_entry_archive_path(entry.public_id),
         params: { archive: { reason: "first" } },
         headers: @staff_headers

    assert_response :see_other

    post edit_org_publishing_docs_app_entry_archive_path(entry.public_id),
         params: { archive: { reason: "second" } },
         headers: @staff_headers

    assert_response :unprocessable_content
    assert_equal "entry is already archived", inertia_props.fetch("errors").fetch("base")
    assert_equal "first", entry.reload.archive_reason
  end

  test "restoring clears the archive state and the operator who set it" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "restore-me", title: "Restore Me")

    post edit_org_publishing_docs_app_entry_archive_path(entry.public_id),
         params: { archive: { reason: "temporary" } },
         headers: @staff_headers

    assert_response :see_other

    delete edit_org_publishing_docs_app_entry_archive_path(entry.public_id), headers: @staff_headers

    assert_response :see_other
    entry.reload

    assert_not entry.archived?
    assert_nil entry.archive_reason
    assert_nil entry.archived_by_operator_public_id
  end

  test "restoring an entry that is not archived is refused" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "not-archived", title: "Not Archived")

    delete edit_org_publishing_docs_app_entry_archive_path(entry.public_id), headers: @staff_headers

    assert_response :unprocessable_content
    assert_equal "entry is not archived", inertia_props.fetch("errors").fetch("base")
  end

  test "archiving through another cell's controller is a 404" do
    com_entry = publishing_draft(audience: "com", surface: "docs", slug: "com-archive", title: "Com")

    post edit_org_publishing_docs_app_entry_archive_path(com_entry.public_id),
         params: { archive: { reason: "no" } },
         headers: @staff_headers

    assert_response :not_found
    assert_not com_entry.reload.archived?
  end

  test "an unauthenticated request cannot archive" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "no-auth-archive", title: "No Auth")

    post edit_org_publishing_docs_app_entry_archive_path(entry.public_id),
         params: { archive: { reason: "nobody" } }

    assert_response :redirect
    assert_not entry.reload.archived?
  end
end
