# typed: false
# frozen_string_literal: true

# Shared receiver checks for the Publishing authority API under
# /api/v0/publishing/:surface/:audience (R5-WU13, one.md section 6.4).
#
# Server-to-server from the Edit RP: the caller proves itself with an edit-org-ww private_key_jwt
# bound to this exact URL and presents the Operator's current Access JWT. The authority itself
# resolves the real Operator, applies the existing PublishingEntryPolicy and calls the existing
# Operations; an RP-supplied boolean or Operator ID is never trusted. Answers are allowlisted JSON.
module PublishingAuthorityApiEndpoint
  extend ActiveSupport::Concern

  EDIT_CLIENT_ID = "edit-org-ww"

  private

  attr_reader :publishing_operator

  def render_forbidden = render(json: { error: "forbidden" }, status: :forbidden)

  def render_not_found = render(json: { error: "not_found" }, status: :not_found)

  def render_bad_request = render(json: { error: "bad_request" }, status: :bad_request)

  def authenticate_publishing_caller!
    response.headers["Cache-Control"] = "no-store"
    unless OidcClientRegistry.authenticate_assertion(
      # The assertion audience is the exact endpoint URL without its query string.
      EDIT_CLIENT_ID, request.headers["X-Client-Assertion"].to_s, token_url: "#{request.base_url}#{request.path}",
    )
      return render(json: { error: "invalid_client" }, status: :unauthorized)
    end

    auth = OidcAccessTokenAuthenticator.call(
      access_token: request.authorization.to_s.delete_prefix("Bearer "), resource_type: "operator",
      host: request.host, authorization_scheme: "Bearer",
    )
    unless auth.success? && auth.payload["client_id"] == EDIT_CLIENT_ID
      return render(json: { error: "invalid_token" }, status: :unauthorized)
    end

    @publishing_operator = auth.resource
  end

  def publishing_entry_class
    # The twelve fixed Publishing cells (four content families x three audiences).
    case [params[:surface], params[:audience]]
    when ["docs", "app"] then Publishing::Docs::App::Entry
    when ["docs", "com"] then Publishing::Docs::Com::Entry
    when ["docs", "org"] then Publishing::Docs::Org::Entry
    when ["help", "app"] then Publishing::Help::App::Entry
    when ["help", "com"] then Publishing::Help::Com::Entry
    when ["help", "org"] then Publishing::Help::Org::Entry
    when ["info", "app"] then Publishing::Info::App::Entry
    when ["info", "com"] then Publishing::Info::Com::Entry
    when ["info", "org"] then Publishing::Info::Org::Entry
    when ["news", "app"] then Publishing::News::App::Entry
    when ["news", "com"] then Publishing::News::Com::Entry
    when ["news", "org"] then Publishing::News::Org::Entry
    else raise ActiveRecord::RecordNotFound
    end
  end

  def publishing_entries_query
    PublishingManagementEntriesQuery.new(entry_class: publishing_entry_class)
  end

  def find_publishing_entry!(key = :entry_ref)
    publishing_entries_query.find!(public_id: params.expect(key))
  end

  def authorize_publishing_entry!(record, to:)
    authorize!(record, to:, with: PublishingEntryPolicy, context: { user: publishing_operator })
  end

  # Re-read through the cell query so every association the serializer needs is preloaded.
  def render_entry(entry, status: :ok)
    fresh = publishing_entries_query.find!(public_id: entry.public_id)
    render json: { entry: PublishingManagementEntrySerializer.detail(fresh) }, status:
  end

  def render_publishing_errors(errors, entry: nil)
    body = { errors: errors.to_h { |key, value| [key.to_s, value] } }
    if entry
      body[:entry] =
        PublishingManagementEntrySerializer.detail(publishing_entries_query.find!(public_id: entry.public_id))
    end
    render json: body, status: :unprocessable_content
  end
end
