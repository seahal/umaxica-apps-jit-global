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

  def reject_authenticated_rp_start!
    return unless request.post?
    return unless logged_in?

    response.set_header("Cache-Control", "no-store")
    render plain: AlreadyAuthenticatedError::MESSAGE, status: :conflict
  end

  def neutral_sign_form_url
    url_for(
      only_path: true,
      ri: RequestContextContract.normalize_region(params[:ri]),
      pt: params[:pt].presence,
    )
  end
end
