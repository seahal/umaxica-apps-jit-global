# typed: false
# frozen_string_literal: true

# Fixed reference ids of the WU-16 authority-stop tables (two.md 5.8 v2, D-172, D-173). The rows
# are inserted by each realm's create migration and mirrored by test fixtures.
module OpAuthorityStopReference
  CAUSES = {
    "browser_logout" => 1,
    "rp_initiated_logout" => 2,
    "token_revocation" => 3,
    "refresh_reuse" => 4,
    "revoke_others" => 5,
    "credential_change" => 6,
    "identity_stop" => 7,
    "administrative" => 8,
    "risk" => 9,
  }.freeze
  SCOPES = { "root" => 1, "grant" => 2, "all_roots_of_principal" => 3 }.freeze
  PARTICIPANT_STATUSES = { "pending" => 1, "acknowledged" => 2, "refused" => 3, "expired" => 4 }.freeze
  FINAL_PARTICIPANT_STATUS_IDS = PARTICIPANT_STATUSES.values_at("acknowledged", "refused", "expired").freeze

  module_function

  def cause_id(cause) = CAUSES.fetch(cause.to_s)

  def scope_id(scope) = SCOPES.fetch(scope.to_s)

  def participant_status_id(status) = PARTICIPANT_STATUSES.fetch(status.to_s)
end
