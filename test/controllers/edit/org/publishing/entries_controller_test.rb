# frozen_string_literal: true

require "test_helper"

class Edit::Org::Publishing::EntriesControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_EDIT_STAFF_URL", "edit.org.localhost")
    host! @host
    @staff = operators(:one)
    @staff_headers = as_staff_headers(@staff, host: @host)
  end

  test "index lists only the cell across locales" do
    ja_entry = publishing_draft(audience: "app", surface: "docs", slug: "ja-guide", title: "JA Guide")
    en_entry = publishing_draft(audience: "app", surface: "docs", slug: "en-guide", title: "EN Guide", locale: "en")
    publishing_draft(audience: "com", surface: "docs", slug: "com-guide", title: "COM Guide")
    publishing_draft(audience: "app", surface: "news", slug: "news-guide", title: "News Guide")

    get edit_org_publishing_docs_app_entries_path(ri: "jp"), headers: @staff_headers

    assert_response :success
    assert_match ja_entry.current_revision.title, response.body
    assert_match en_entry.current_revision.title, response.body
    assert_no_match(/COM Guide/, response.body)
    assert_no_match(/News Guide/, response.body)
    assert_select "td", text: "ja"
    assert_select "td", text: "en"
  end

  test "empty index renders" do
    get edit_org_publishing_help_org_entries_path(ri: "jp"), headers: @staff_headers

    assert_response :success
    # rubocop:disable I18n/RailsI18n/DecorateString -- asserting on inline staff-only copy, not user-facing i18n text
    assert_match "No entries in this cell.", response.body
    # rubocop:enable I18n/RailsI18n/DecorateString
  end

  test "show renders the cell entry and 404s for other cells or unknown ids" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "shown", title: "Shown")
    foreign = publishing_draft(audience: "com", surface: "docs", slug: "foreign", title: "Foreign")

    get edit_org_publishing_docs_app_entry_path(entry.public_id, ri: "jp"), headers: @staff_headers

    assert_response :success
    assert_match entry.public_id, response.body
    assert_select "dd", text: "docs"
    assert_select "dd", text: "app"
    assert_match "Shown", response.body

    get edit_org_publishing_docs_app_entry_path(foreign.public_id, ri: "jp"), headers: @staff_headers

    assert_response :not_found

    get edit_org_publishing_docs_app_entry_path("does-not-exist-publicid", ri: "jp"), headers: @staff_headers

    assert_response :not_found

    get edit_org_publishing_docs_app_entry_path(entry.id, ri: "jp"), headers: @staff_headers

    assert_response :not_found
  end

  test "edit renders current revision values and 404s for another cell" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "editable", title: "Editable")
    foreign = publishing_draft(audience: "com", surface: "docs", slug: "other", title: "Other")

    get edit_edit_org_publishing_docs_app_entry_path(entry.public_id, ri: "jp"), headers: @staff_headers

    assert_response :success
    assert_select "input[name='entry[title]'][value=?]", "Editable"
    assert_match "Editable body", response.body
    assert_select "form[action=?]", edit_org_publishing_docs_app_entry_path(entry.public_id, ri: "jp")
    assert_select "input[name='_method'][value='patch']"

    get edit_edit_org_publishing_docs_app_entry_path(foreign.public_id, ri: "jp"), headers: @staff_headers

    assert_response :not_found
  end

  test "successful update creates a new revision and preserves taxonomy and media" do
    category = publishing_category_vocabulary(audience: "app", surface: "docs")
    term = publishing_term(vocabulary: category, locale: "ja", slug: "guide", name: "ガイド")
    entry = publishing_draft(audience: "app", surface: "docs", slug: "updated", title: "Original")
    previous = entry.current_revision
    create_single_assignment(entry_revision: previous, vocabulary: category, taxonomy_term: term, locale: "ja")
    media_file = publishing_media_file
    publishing_revision_media_usage(revision: previous, media_file:)

    patch edit_org_publishing_docs_app_entry_path(entry.public_id),
          params: {
            entry: {
              title: "Revised",
              summary: "New summary",
              body: { "text" => "New body" }.to_json,
              lock_version: entry.lock_version,
            },
          },
          headers: @staff_headers

    assert_redirected_to edit_org_publishing_docs_app_entry_path(entry.public_id)
    assert_equal 303, response.status
    entry.reload

    assert_not_equal previous.id, entry.current_revision_id
    assert_equal 2, entry.current_revision.sequence
    assert_equal "Revised", entry.current_revision.title
    assert_equal "New summary", entry.current_revision.summary
    assert_equal({ "text" => "New body" }, entry.current_revision.body)
    previous.reload

    assert_equal "Original", previous.title
    assert_equal term.id, entry.current_revision.single_taxonomy_assignments.sole.taxonomy_term_id
    assert_equal media_file.id, entry.current_revision.media_usages.sole.media_file_id
  end

  test "malformed body json returns 422 and does not create a revision" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "invalid-json", title: "Keep")
    current = entry.current_revision

    patch edit_org_publishing_docs_app_entry_path(entry.public_id),
          params: {
            entry: {
              title: "Keep",
              summary: "Keep summary",
              body: "{not-json",
              lock_version: entry.lock_version,
            },
          },
          headers: @staff_headers

    assert_response :unprocessable_content
    assert_match "must be valid JSON", response.body
    assert_equal current, entry.reload.current_revision
    assert_equal 1, entry.revisions.count
  end

  test "blank title returns 422 without a partial revision" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "blank-title", title: "Keep")

    patch edit_org_publishing_docs_app_entry_path(entry.public_id),
          params: {
            entry: {
              title: "",
              summary: "x",
              body: { "text" => "x" }.to_json,
              lock_version: entry.lock_version,
            },
          },
          headers: @staff_headers

    assert_response :unprocessable_content
    assert_equal 1, entry.revisions.count
  end

  # Two staff members editing the same entry: the second submit carries the lock_version its edit
  # form rendered, which the first submit has already moved past. That has to come back as the
  # editable form with the reason on it, not as a silent overwrite of the revision it never saw.
  test "a stale lock_version returns 422 with the current revision still in place" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "concurrent", title: "Original")
    stale_lock_version = entry.lock_version

    patch edit_org_publishing_docs_app_entry_path(entry.public_id),
          params: {
            entry: {
              title: "First writer",
              summary: "first",
              body: { "text" => "first" }.to_json,
              lock_version: stale_lock_version,
            },
          },
          headers: @staff_headers

    assert_response :see_other
    first_revision = entry.reload.current_revision

    patch edit_org_publishing_docs_app_entry_path(entry.public_id),
          params: {
            entry: {
              title: "Second writer",
              summary: "second",
              body: { "text" => "second" }.to_json,
              lock_version: stale_lock_version,
            },
          },
          headers: @staff_headers

    assert_response :unprocessable_content
    assert_match "is stale", response.body
    assert_equal first_revision, entry.reload.current_revision
    assert_equal 2, entry.revisions.count
  end

  test "update under docs/app does not mutate a docs/com entry" do
    app_entry = publishing_draft(audience: "app", surface: "docs", slug: "app-one", title: "App")
    com_entry = publishing_draft(audience: "com", surface: "docs", slug: "com-one", title: "Com")
    com_revision = com_entry.current_revision

    patch edit_org_publishing_docs_app_entry_path(com_entry.public_id),
          params: {
            entry: {
              title: "Hijack",
              summary: "no",
              body: { "text" => "no" }.to_json,
              lock_version: com_entry.lock_version,
            },
          },
          headers: @staff_headers

    assert_response :not_found
    assert_equal com_revision, com_entry.reload.current_revision
    assert_equal 1, app_entry.revisions.count
  end

  # The CMS reads and writes unpublished content: drafts that were never published, the bodies of
  # archived entries, and the revision history behind a published page. None of it is public.
  test "an unauthenticated request cannot read the CMS" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "private-draft", title: "Private Draft")

    get edit_org_publishing_docs_app_entries_path(ri: "jp")

    assert_response :redirect
    assert_no_match(/Private Draft/, response.body)

    get edit_org_publishing_docs_app_entry_path(entry.public_id, ri: "jp")

    assert_response :redirect
    assert_no_match(/Private Draft/, response.body)
  end

  test "an unauthenticated request cannot revise an entry" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "unauthenticated-write", title: "Original")

    patch edit_org_publishing_docs_app_entry_path(entry.public_id),
          params: {
            entry: {
              title: "Written by nobody",
              summary: "no",
              body: { "text" => "no" }.to_json,
              lock_version: entry.lock_version,
            },
          }

    assert_response :redirect
    assert_equal "Original", entry.reload.current_revision.title
    assert_equal 1, entry.revisions.count
  end

  test "new renders an empty create form for the cell" do
    get new_edit_org_publishing_docs_app_entry_path(ri: "jp"), headers: @staff_headers

    assert_response :success
    assert_select "form[action=?]", edit_org_publishing_docs_app_entries_path(ri: "jp")
    assert_select "input[name='_method']", false
    assert_select "input[name='entry[title]']"
    assert_select "select[name='entry[locale]'] option", count: 2
  end

  test "create makes the entry, its canonical slug, and revision 1 in the cell that was posted to" do
    post edit_org_publishing_docs_app_entries_path,
         params: {
           entry: {
             title: "Created",
             summary: "Created summary",
             body: { "text" => "Created body" }.to_json,
             locale: "ja",
             slug: "created-entry",
           },
         },
         headers: @staff_headers

    assert_response :see_other
    entry = Publishing::Docs::App::Entry.find_by!(locale: "ja", public_id: response.location[%r{entries/([^/?]+)}, 1])

    assert_equal "created-entry", entry.canonical_slug.slug
    assert_equal "canonical", entry.canonical_slug.state
    assert_equal 1, entry.current_revision.sequence
    assert_equal "Created", entry.current_revision.title
    assert_equal({ "text" => "Created body" }, entry.current_revision.body)
    assert_equal @staff.public_id, entry.current_revision.created_by_operator_public_id
    assert_nil entry.active_publication
    assert_equal 0, Publishing::Docs::Com::Entry.where(locale: "ja").count
  end

  test "a slug already used in the same locale returns 422 without creating a second entry" do
    publishing_draft(audience: "app", surface: "docs", slug: "taken", title: "First")

    post edit_org_publishing_docs_app_entries_path,
         params: {
           entry: {
             title: "Second",
             summary: "s",
             body: { "text" => "b" }.to_json,
             locale: "ja",
             slug: "taken",
           },
         },
         headers: @staff_headers

    assert_response :unprocessable_content
    assert_match "is already used by another entry in this locale", response.body
    assert_equal 1, Publishing::Docs::App::Entry.where(locale: "ja").count
  end

  test "a slug the database format check would reject is refused by the form" do
    post edit_org_publishing_docs_app_entries_path,
         params: {
           entry: {
             title: "Bad slug",
             summary: "s",
             body: { "text" => "b" }.to_json,
             locale: "ja",
             slug: "Not A Slug",
           },
         },
         headers: @staff_headers

    assert_response :unprocessable_content
    assert_match "must be lowercase letters, digits, and hyphens", response.body
    assert_equal 0, Publishing::Docs::App::Entry.count
  end

  test "create refuses a locale the application does not serve" do
    post edit_org_publishing_docs_app_entries_path,
         params: {
           entry: {
             title: "Wrong locale",
             summary: "s",
             body: { "text" => "b" }.to_json,
             locale: "fr",
             slug: "wrong-locale",
           },
         },
         headers: @staff_headers

    assert_response :unprocessable_content
    assert_match "must be one of en, ja", response.body
    assert_equal 0, Publishing::Docs::App::Entry.count
  end

  test "the index is paged and does not return the whole cell" do
    27.times { |index|
      publishing_draft(audience: "app", surface: "docs", slug: "paged-#{index}", title: "Paged #{index}")
    }

    get edit_org_publishing_docs_app_entries_path(ri: "jp"), headers: @staff_headers

    assert_response :success
    assert_select "table tbody tr", count: 25
    assert_match "27 entries", response.body
    assert_match "page 1", response.body
    assert_select "nav a", text: "Previous", count: 0

    next_href = css_select("nav a").find { |node| node.text == "Next" }.attribute("href").value
    get next_href, headers: @staff_headers

    assert_response :success
    assert_select "table tbody tr", count: 2
    assert_select "nav a", text: "Next", count: 0
  end

  test "a page that is not a number is a bad request rather than page one" do
    get edit_org_publishing_docs_app_entries_path(ri: "jp", page: "second"), headers: @staff_headers

    assert_response :bad_request
  end

  test "the operator who revised an entry is recorded on the revision" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "provenance", title: "Original")

    patch edit_org_publishing_docs_app_entry_path(entry.public_id),
          params: {
            entry: {
              title: "Revised",
              summary: "s",
              body: { "text" => "b" }.to_json,
              lock_version: entry.lock_version,
            },
          },
          headers: @staff_headers

    assert_response :see_other
    assert_equal @staff.public_id, entry.reload.current_revision.created_by_operator_public_id
  end
end
