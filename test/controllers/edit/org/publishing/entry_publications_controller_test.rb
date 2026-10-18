# frozen_string_literal: true

require "test_helper"

class Edit::Org::Publishing::EntryPublicationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_EDIT_STAFF_URL")
    host! @host
    @staff = operators(:one)
    @staff_headers =
      begin
        rp_headers = as_staff_headers(@staff, host: @host)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "org"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpOrgGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpOrgGrant.create!(
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "operator",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "operator",
                                     ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
  end

  test "publishing promotes the current revision and opens a window the public read path returns" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "to-publish", title: "To Publish")

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id), headers: @staff_headers

    assert_response :see_other
    entry = publication_entry_for_test(entry)
    publication = entry.active_publication

    assert_not_nil publication
    assert_equal entry.current_revision_id,
                 Publishing::Docs::App::EntryVersion.find(publication.entry_version_id).entry_revision_id
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
    first = publication_entry_for_test(entry).active_publication

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id), headers: @staff_headers

    assert_response :see_other
    entry = publication_entry_for_test(entry)

    assert_equal first.id, entry.active_publication.id
    assert_equal 1, publication_entry_for_test(entry).publications.count
    assert_equal 1, entry.versions.count
  end

  test "publishing a new revision terminates the live window at the instant the new one starts" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "superseded", title: "First")

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id), headers: @staff_headers

    assert_response :see_other
    first_publication = publication_entry_for_test(entry).active_publication

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
    entry = publication_entry_for_test(entry)
    first_publication.reload
    current = entry.active_publication

    assert_not_equal first_publication.id, current.id
    assert_equal "superseded by a newer version", first_publication.termination_reason
    assert_equal @staff.public_id, first_publication.ended_by_operator_public_id
    assert_equal first_publication.effective_until, current.effective_from
    assert_equal "Second", Publishing::Docs::App::EntryVersion.find(current.entry_version_id).title
    assert_equal 2, entry.versions.count
  end

  test "an effective_from in the future schedules a window that is not live yet" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "scheduled", title: "Scheduled")

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id),
         params: { publication: { effective_from: 2.days.from_now.iso8601 } },
         headers: @staff_headers

    assert_response :see_other
    entry.reload

    assert_nil publication_entry_for_test(entry).active_publication
    assert_equal 1, publication_entry_for_test(entry).publications.count
    assert_operator publication_entry_for_test(entry).publications.sole.effective_from, :>, Time.current
  end

  test "an effective_from that is not a date is refused on the entry page" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "bad-date", title: "Bad Date")

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id),
         params: { publication: { effective_from: "next tuesday-ish" } },
         headers: @staff_headers

    assert_response :unprocessable_content
    assert_match "must be a date and time", response.body
    assert_equal 0, publication_entry_for_test(entry.reload).publications.count
  end

  test "an entry with no current revision cannot be published" do
    entry = Publishing::Docs::App::Entry.create!(locale: "ja")

    post edit_org_publishing_docs_app_entry_publications_path(entry.public_id), headers: @staff_headers

    assert_response :unprocessable_content
    assert_match "entry has no current revision to publish", response.body
    assert_equal 0, publication_entry_for_test(entry.reload).publications.count
  end

  test "unpublishing without a reason is refused because the row cannot hold one" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "no-reason", title: "No Reason")
    publishing_publish(entry: entry)
    publication = publication_entry_for_test(entry).active_publication

    delete edit_org_publishing_docs_app_entry_publication_path(entry.public_id, publication.public_id),
           headers: @staff_headers

    assert_response :unprocessable_content
    assert_select "span#publication_reason-error", text: "can't be blank"
    assert_not_nil publication_entry_for_test(entry).active_publication
  end

  test "unpublishing terminates the live window and removes the entry from the public read path" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "unpublish", title: "Unpublish")
    publishing_publish(entry: entry)
    publication = publication_entry_for_test(entry).active_publication

    delete edit_org_publishing_docs_app_entry_publication_path(entry.public_id, publication.public_id),
           params: { publication: { reason: "withdrawn by legal" } },
           headers: @staff_headers

    assert_response :see_other
    publication.reload

    assert_equal "withdrawn by legal", publication.termination_reason
    assert_equal publication.terminated_at, publication.effective_until
    assert_equal @staff.public_id, publication.ended_by_operator_public_id
    assert_nil publication_entry_for_test(entry).active_publication
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
    scheduled = publication_entry_for_test(entry).publications.sole

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
    publication = publication_entry_for_test(entry).active_publication

    delete edit_org_publishing_docs_app_entry_publication_path(entry.public_id, publication.public_id),
           params: { publication: { reason: "first" } },
           headers: @staff_headers

    assert_response :see_other

    delete edit_org_publishing_docs_app_entry_publication_path(entry.public_id, publication.public_id),
           params: { publication: { reason: "second" } },
           headers: @staff_headers

    assert_response :unprocessable_content
    assert_match "publication has already ended", response.body
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

  private

  def publication_entry_for_test(entry)
    Publishing::Docs::App::Entry.includes(
      :current_revision, :publications, :versions, active_publication: :entry_version,
    ).find(entry.id)
  end
end
