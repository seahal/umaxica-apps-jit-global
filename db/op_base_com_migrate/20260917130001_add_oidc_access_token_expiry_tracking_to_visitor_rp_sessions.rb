# typed: false
# frozen_string_literal: true

class AddOidcAccessTokenExpiryTrackingToVisitorRpSessions < ActiveRecord::Migration[8.2]
  def change
    add_column(:visitor_rp_sessions, :oidc_access_token_max_expires_at, :datetime)
  end
end
