# frozen_string_literal: true

require "test_helper"

class Edit::Org::Publishing::EntryPublicationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_EDIT_STAFF_URL", "edit.org.localhost")
    host! @host
    @staff = operators(:one)
    @staff_headers = as_staff_headers(@staff, host: @host)
  end

  test "publishing promotes the current revision and opens a window the public read path returns" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "to-publish", title: "To Publish")

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id), headers: @staff_headers

    assert_response :see_other
    entry.reload
    publication = entry.active_publication

    assert_not_nil publication
    assert_equal entry.current_revision.id, publication.entry_version.entry_revision_id
    assert_equal @staff.public_id, publication.created_by_operator_public_id
    assert_equal @staff.public_id, entry.versions.sole.created_by_operator_public_id
    assert_equal(
      entry,
      PublishingPublishedEntriesQuery.new(entry_class: Publishing::Docs::App::Entry, locale: "ja")
        .find_published(public_id: entry.public_id),
    )
  end

  test "publishing an unchanged entry again does not open a second window" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "twice", title: "Twice")

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id), headers: @staff_headers

    assert_response :see_other
    first = entry.reload.active_publication

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id), headers: @staff_headers

    assert_response :see_other
    entry.reload

    assert_equal first.id, entry.active_publication.id
    assert_equal 1, entry.publications.count
    assert_equal 1, entry.versions.count
  end

  test "publishing a new revision terminates the live window at the instant the new one starts" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "superseded", title: "First")

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id), headers: @staff_headers

    assert_response :see_other
    first_publication = entry.reload.active_publication

    patch edit_org_publishing_docs_app_entry_path(entry.public_id),
          params: {
            entry: {
              title: "Second",
              summary: "s",
              body: { "text" => "second" }.to_json,
              lock_version: entry.reload.lock_version,
            },
          },
          headers: @staff_headers

    assert_response :see_other

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id), headers: @staff_headers

    assert_response :see_other
    entry.reload
    first_publication.reload
    current = entry.active_publication

    assert_not_equal first_publication.id, current.id
    assert_equal "superseded by a newer version", first_publication.termination_reason
    assert_equal @staff.public_id, first_publication.ended_by_operator_public_id
    assert_equal first_publication.effective_until, current.effective_from
    assert_equal "Second", current.entry_version.title
    assert_equal 2, entry.versions.count
  end

  test "an effective_from in the future schedules a window that is not live yet" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "scheduled", title: "Scheduled")

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id),
         params: { publication: { effective_from: 2.days.from_now.iso8601 } },
         headers: @staff_headers

    assert_response :see_other
    entry.reload

    assert_nil entry.active_publication
    assert_equal 1, entry.publications.count
    assert_operator entry.publications.sole.effective_from, :>, Time.current
  end

  test "an effective_from that is not a date is refused on the entry page" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "bad-date", title: "Bad Date")

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id),
         params: { publication: { effective_from: "next tuesday-ish" } },
         headers: @staff_headers

    assert_response :unprocessable_content
    assert_equal "edit/org/publishing/docs/app/entries/show", inertia_component
    assert_equal "must be a date and time", inertia_props.fetch("errors").fetch("effective_from")
    assert_equal 0, entry.reload.publications.count
  end

  test "an entry with no current revision cannot be published" do
    entry = Publishing::Docs::App::Entry.create!(locale: "ja")

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id), headers: @staff_headers

    assert_response :unprocessable_content
    assert_equal "entry has no current revision to publish", inertia_props.fetch("errors").fetch("base")
    assert_equal 0, entry.reload.publications.count
  end

  test "unpublishing without a reason is refused because the row cannot hold one" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "no-reason", title: "No Reason")
    publishing_publish(entry: entry)
    publication = entry.reload.active_publication

    delete edit_org_publishing_docs_app_entry_publication_path(entry.public_id, publication.public_id),
           headers: @staff_headers

    assert_response :unprocessable_content
    assert_equal "can't be blank", inertia_props.fetch("errors").fetch("reason")
    assert_not_nil entry.reload.active_publication
  end

  test "unpublishing terminates the live window and removes the entry from the public read path" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "unpublish", title: "Unpublish")
    publishing_publish(entry: entry)
    publication = entry.reload.active_publication

    delete edit_org_publishing_docs_app_entry_publication_path(entry.public_id, publication.public_id),
           params: { publication: { reason: "withdrawn by legal" } },
           headers: @staff_headers

    assert_response :see_other
    publication.reload

    assert_equal "withdrawn by legal", publication.termination_reason
    assert_equal publication.terminated_at, publication.effective_until
    assert_equal @staff.public_id, publication.ended_by_operator_public_id
    assert_nil entry.reload.active_publication
    assert_nil(
      PublishingPublishedEntriesQuery.new(entry_class: Publishing::Docs::App::Entry, locale: "ja")
        .find_published(public_id: entry.public_id),
    )
  end

  test "cancelling a scheduled window records a cancellation rather than a termination" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "cancel-scheduled", title: "Scheduled")

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id),
         params: { publication: { effective_from: 3.days.from_now.iso8601 } },
         headers: @staff_headers

    assert_response :see_other
    scheduled = entry.reload.publications.sole

    delete edit_org_publishing_docs_app_entry_publication_path(entry.public_id, scheduled.public_id),
           params: { publication: { reason: "campaign called off" } },
           headers: @staff_headers

    assert_response :see_other
    scheduled.reload

    assert_equal "campaign called off", scheduled.cancellation_reason
    assert_not_nil scheduled.cancelled_at
    assert_nil scheduled.terminated_at
  end

  test "a window that has already ended cannot be ended twice" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "ended-twice", title: "Ended Twice")
    publishing_publish(entry: entry)
    publication = entry.reload.active_publication

    delete edit_org_publishing_docs_app_entry_publication_path(entry.public_id, publication.public_id),
           params: { publication: { reason: "first" } },
           headers: @staff_headers

    assert_response :see_other

    delete edit_org_publishing_docs_app_entry_publication_path(entry.public_id, publication.public_id),
           params: { publication: { reason: "second" } },
           headers: @staff_headers

    assert_response :unprocessable_content
    assert_equal "publication has already ended", inertia_props.fetch("errors").fetch("base")
    assert_equal "first", publication.reload.termination_reason
  end

  test "publishing through another cell's controller is a 404" do
    com_entry = publishing_draft(audience: "com", surface: "docs", slug: "com-entry", title: "Com")

    post edit_org_publishing_docs_app_entry_publications_path(com_entry.public_id), headers: @staff_headers

    assert_response :not_found
    assert_equal 0, com_entry.reload.publications.count
  end

  test "an unauthenticated request cannot publish" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "no-auth-publish", title: "No Auth")

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id)

    assert_response :redirect
    assert_equal 0, entry.reload.publications.count
    assert_equal 0, entry.versions.count
  end
end
