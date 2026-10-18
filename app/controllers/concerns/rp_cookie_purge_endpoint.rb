# typed: false
# frozen_string_literal: true

# RP cookie purge after OP logout (R5-WU16, one.md section 7.6).
#
# POST /sign/out/purge with the logged-out `sid`. The browser's RP credentials are cleared only when
# they belong to exactly that sid AND this cell already holds the absorbing tombstone for it, so a
# stale or replayed purge can never destroy a newer login in the same browser. Answering this
# request is not proof that the browser deleted anything, and it is never the logout itself.
module RpCookiePurgeEndpoint
  extend ActiveSupport::Concern

  public

  def create
    response.set_header("Cache-Control", "no-store")
    sid = params.expect(:sid).to_s
    cell = RpCellBinding.for_client(browser_rp_client_id)
    # The credential as the browser presented it, before any earlier filter acted on it.
    access_token = request.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.scrub
    presented_sid = access_token.present? && JWT.decode(access_token, nil, false).first["sid"].to_s

    if presented_sid == sid && tombstoned?(cell, sid)
      clear_browser_rp_cookies!
      render json: { purged: true }
    else
      render json: { purged: false }
    end
  rescue JWT::DecodeError
    render json: { purged: false }
  end

  private

  def tombstoned?(cell, sid)
    "#{cell.record_prefix}OpSessionBinding".constantize.where(client_id: cell.client_id, sid:)
      .where.not(revoked_at: nil).exists?
  end
end
