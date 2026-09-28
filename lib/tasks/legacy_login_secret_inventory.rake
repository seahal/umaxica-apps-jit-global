# frozen_string_literal: true

require "fileutils"
require "json"

namespace :secret_credentials do
  # Read-only. Legacy permanent App LOGIN rows are `user_secret_kind_id = LOGIN` with no new-axis
  # `secret_kind`. New-axis rows (Emergency `temporary_access`, RecoveryPasscodes) also default to
  # the LOGIN kind id, so the kind id alone must never select rows for revocation.
  desc "Inventory legacy App LOGIN secret credentials without changing data"
  task legacy_login_inventory: :environment do
    report_path = ENV.fetch("REPORT", "tmp/secret_credentials/legacy_login_inventory.json")
    login = ClientSecretCredential.where(user_secret_kind_id: ClientSecretCredentialKind::LOGIN)
    legacy = login.where(secret_kind: nil)
    now = Time.current
    report = {
      generated_at: now.iso8601,
      login_kind_rows: login.count,
      new_axis_login_kind_rows_by_secret_kind: login.where.not(secret_kind: nil).group(:secret_kind).count,
      legacy_rows: legacy.count,
      legacy_rows_by_status_id: legacy.group(:user_identity_secret_status_id).count,
      legacy_rows_already_discarded: legacy.where(discard_at: ..now).count,
      legacy_rows_with_revoked_at: legacy.where.not(revoked_at: nil).count,
      legacy_rows_pending_revocation: legacy.where(revoked_at: nil).where("discard_at > ?", now).count,
    }
    path = Rails.root.join(report_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, JSON.pretty_generate(report))
    puts JSON.pretty_generate(report)
    puts "Report written to #{report_path}"
  end
end
