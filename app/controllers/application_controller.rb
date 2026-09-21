# typed: false
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  AUTHENTICATION_MODE = :deny_all

  # Repository-wide CSRF baseline: Rails 8.2 Fetch Metadata verification with a fallback to the
  # legacy authenticity token for clients that omit Sec-Fetch-Site. `with: :exception` is stated
  # explicitly so a failed check always raises rather than depending on the framework default,
  # which would otherwise make the failure mode a silent consequence of `config.load_defaults`.
  # Every surface root controller repeats this declaration; keep them consistent.
  protect_from_forgery using: :header_or_legacy_token, with: :exception

  private

  def cross_host_redirect_allowed?
    true
  end
end
