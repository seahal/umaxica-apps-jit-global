# typed: false
# frozen_string_literal: true

# GET /sign/interruption on every first-party RP (D-153): one generic page for every expected
# abnormal ending of the sign flow. It shows no reason, needs no sign-in, branches on nothing,
# writes nothing and never redirects on its own; the reason was logged by the callback.
module OidcRpSignInterruption
  extend ActiveSupport::Concern

  public

  def show
    response.set_header("Cache-Control", "no-store")
    render template: "shared/oidc_rp_sign_interruptions/show", layout: false
  end

  private

  def interruption_sign_path
    "/sign?#{{ ri: RequestContextContract.normalize_region(params[:ri]) }.compact.to_query}"
  end

  def browser_rp_invalid_credentials_are_ignored?
    true
  end
end
