# frozen_string_literal: true

require "test_helper"

class Edit::Org::Publishing::EntryArchivesControllerTest < ActionDispatch::IntegrationTest
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
              authentication_epoch: 0,
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
    assert_select "#archive_reason-error", text: "can't be blank"
    assert_select "input[aria-invalid=true][aria-describedby=archive_reason-error]"
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
    assert_match "a published entry cannot be archived; end its publication first", response.body
    assert_not entry.reload.archived?

    publication = Publishing::Docs::App::Publication.active.find_by!(entry_id: entry.id)

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
    assert_match "entry is already archived", response.body
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
    assert_match "entry is not archived", response.body
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
