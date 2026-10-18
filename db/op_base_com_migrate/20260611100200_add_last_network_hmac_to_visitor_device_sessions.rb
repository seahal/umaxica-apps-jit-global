# typed: false
# frozen_string_literal: true

# Adds a coarse, privacy-preserving network fingerprint to visitor device
# sessions: an HMAC of the /24 (IPv4) or /48 (IPv6) network, never the full IP.
# Used as a same-session change signal for IP-anomaly detection. Additive and
# nullable so it is backward-compatible and reversible. See
# adr/ip-anomaly-session-revocation.md.
class AddLastNetworkHmacToVisitorDeviceSessions < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :visitor_device_sessions, :last_network_hmac, :string
  end
end
