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
    url = initiate_oidc_session!(target_link_uri: params[:target_link_uri])
    # The start is a POST; 303 makes the browser fetch the authorization endpoint with GET.
    redirect_to_oidc_authorization_url(url, status: :see_other)
  end

  private

  def preference_entry_recovery_action?
    action_name == "create"
  end

  def browser_rp_invalid_credentials_are_ignored?
    true
  end

  def reject_authenticated_rp_start!
    return unless request.post?
    return unless logged_in?

    response.set_header("Cache-Control", "no-store")
    render plain: I18n.t("errors.messages.operation_not_permitted"), status: :forbidden,
           content_type: "text/plain"
  end

  def neutral_sign_form_url
    url_for(only_path: true, ri: RequestContextContract.normalize_region(params[:ri]))
  end

  # D-151: GET /sign keeps the protected page's path as a hidden field for POST /sign.
  def neutral_sign_target_link_uri
    RpTargetLinkUri.normalize(params[:target_link_uri])
  end
end
