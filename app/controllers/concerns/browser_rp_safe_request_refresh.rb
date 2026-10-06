# typed: false
# frozen_string_literal: true

# Safe Browser RP requests may refresh only when the access credential is not
# usable. An access-valid GET/HEAD never touches the refresh authority.
module BrowserRpSafeRequestRefresh
  extend ActiveSupport::Concern

  included do
    include BrowserRpAuthentication

    before_action :authenticate_browser_rp_safe_request!
  end

  public

  def authenticate_browser_rp_safe_request!
    return if request.post? || request.patch? || request.put? || request.delete? || request.options?
    return if browser_rp_authenticated? || browser_rp_dependency_failed?
    return if refresh_browser_rp_credentials! == :dependency

    browser_rp_access_state
  end
end
