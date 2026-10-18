# frozen_string_literal: true

# adr/operator-capability-authorization.md: the platform-scoped capability grant store. Every
# vocabulary column is CHECK-constrained so a grant can only name a capability the application
# catalog defines; adding a capability is a migration, never a data-only change.
class CreateOperatorCapabilityGrants < ActiveRecord::Migration[8.2]
  CAPABILITIES = %w(
    support.console.read
    support.account.read.app
    support.account.read.com
    support.session.revoke.app
    support.session.revoke.com
    enforcement.read.app
    enforcement.read.com
    enforcement.apply.app
    enforcement.apply.com
    enforcement.approve.app
    enforcement.approve.com
    enforcement.release.app
    enforcement.release.com
    enforcement.review_appeal.app
    enforcement.review_appeal.com
    iam.capability.read
    iam.capability.grant
    iam.capability.revoke
  ).freeze
  GRANT_REASON_CODES = %w(bootstrap duty_assignment incident_response access_review).freeze
  REVOKE_REASON_CODES = %w(duty_ended access_review security_incident operator_error_recovery).freeze

  # rubocop:disable Metrics/MethodLength
  def change
    create_table(:operator_capability_grants, id: :bigserial) do |t|
      t.string(:public_id, limit: 21, null: false)
      t.references(:operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.string(:capability, null: false)
      t.string(:origin, null: false)
      t.references(:granted_by_operator, foreign_key: { to_table: :operators }, index: false)
      t.string(:reason_code, null: false)
      t.string(:ticket_id, limit: 64)
      t.datetime(:starts_at, null: false)
      t.datetime(:expires_at, null: false)
      t.datetime(:revoked_at)
      t.references(:revoked_by_operator, foreign_key: { to_table: :operators }, index: false)
      t.string(:revoke_reason_code)
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps

      t.index(:public_id, unique: true, name: "idx_operator_capability_grants_public_id")
      t.index(%i(operator_id capability), name: "idx_operator_capability_grants_operator_capability")
      t.index(
        %i(capability operator_id),
        where: "revoked_at IS NULL",
        name: "idx_operator_capability_grants_unrevoked_capability",
      )
    end

    add_check_constraint(
      :operator_capability_grants,
      "capability IN (#{quoted_list(CAPABILITIES)})",
      name: "chk_operator_capability_grants_capability",
    )
    add_check_constraint(
      :operator_capability_grants,
      "origin IN ('grant', 'bootstrap')",
      name: "chk_operator_capability_grants_origin",
    )
    # A delegated grant always names a granter other than the grantee; a bootstrap grant never
    # names one, so self-grant cannot be expressed in either shape.
    add_check_constraint(
      :operator_capability_grants,
      "(origin = 'grant' AND granted_by_operator_id IS NOT NULL AND granted_by_operator_id <> operator_id) " \
      "OR (origin = 'bootstrap' AND granted_by_operator_id IS NULL)",
      name: "chk_operator_capability_grants_granter",
    )
    add_check_constraint(
      :operator_capability_grants,
      "reason_code IN (#{quoted_list(GRANT_REASON_CODES)}) AND ((origin = 'bootstrap') = (reason_code = 'bootstrap'))",
      name: "chk_operator_capability_grants_reason_code",
    )
    add_check_constraint(
      :operator_capability_grants,
      "isfinite(starts_at) AND isfinite(expires_at) AND expires_at > starts_at " \
      "AND expires_at <= starts_at + interval '366 days'",
      name: "chk_operator_capability_grants_validity_window",
    )
    add_check_constraint(
      :operator_capability_grants,
      "(revoked_at IS NULL AND revoke_reason_code IS NULL AND revoked_by_operator_id IS NULL) " \
      "OR (revoked_at IS NOT NULL AND revoke_reason_code IS NOT NULL " \
      "AND revoke_reason_code IN (#{quoted_list(REVOKE_REASON_CODES)}))",
      name: "chk_operator_capability_grants_revocation",
    )
  end
  # rubocop:enable Metrics/MethodLength

  private

  def quoted_list(values)
    values.map { |value| "'#{value}'" }.join(", ")
  end
end
