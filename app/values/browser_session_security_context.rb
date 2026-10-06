# typed: false
# frozen_string_literal: true

# The live security state carried by a Browser Session and consumed through an
# authenticated RP credential. This value is not itself an authentication
# credential; callers must already have verified the RP access token and its
# RP Session binding before constructing it.
class BrowserSessionSecurityContext < Data.define(
  :resource,
  :browser_session,
  :root_token,
  :rp_session,
  :access_payload,
)
  public

  def active?
    browser_session&.usable? && root_token&.currently_usable? && rp_session&.active?
  end

  def restricted?
    root_token&.respond_to?(:restricted?) && root_token.restricted?
  end

  def root_session_public_id
    root_token&.public_id
  end

  def rp_session_public_id
    rp_session&.public_id
  end
end
