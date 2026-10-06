# typed: false
# frozen_string_literal: true

# The browser RP entry is deliberately neutral. It renders on GET and creates
# an OIDC transaction only on the CSRF-protected POST.
module OidcRpSignEntry
  extend ActiveSupport::Concern

  public

  def show
    response.set_header("Cache-Control", "no-store")
    render template: "shared/oidc_rp_sign_entries/show", layout: false
  end

  def create
    response.set_header("Cache-Control", "no-store")
    url = initiate_oidc_session!(pt: params[:pt].presence || "/")
    redirect_to_oidc_authorization_url(url)
  end

  private

  def browser_rp_invalid_credentials_are_ignored?
    true
  end

  def reject_authenticated_rp_start!
    return unless request.post?
    return unless logged_in? || authenticated_rp_browser?

    response.set_header("Cache-Control", "no-store")
    render plain: I18n.t("errors.messages.operation_not_permitted"), status: :forbidden,
           content_type: "text/plain"
  end

  def authenticated_rp_browser?
    access_token = cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.presence
    return false unless access_token

    client = OidcClientRegistry.find!(oidc_client_id)
    resource_type = OidcIssuer.resource_type_for_client(client)
    OidcRpBrowserCredentialContract.decode_access_token(
      token: access_token,
      host: request.host,
      resource_type: resource_type,
      client_id: client.client_id,
    ).present?
  end

  def neutral_sign_form_url
    url_for(
      only_path: true,
      ri: RequestContextContract.normalize_region(params[:ri]),
      pt: params[:pt].presence,
    )
  end
end
