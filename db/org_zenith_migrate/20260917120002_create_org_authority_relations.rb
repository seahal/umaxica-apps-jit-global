# frozen_string_literal: true

class CreateOrgAuthorityRelations < ActiveRecord::Migration[8.2]
  # Keep every authority relation explicit so the schema contract can be reviewed one table at a
  # time. The resulting migration is intentionally longer than a generated abstraction.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def change
    create_table(:operator_authority_locks, id: :bigserial) do |t|
      t.references(:operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.timestamps

      t.index(:operator_id, unique: true, name: "idx_operator_authority_locks_on_operator_id")
    end

    create_table(:agent_ownerships, id: :bigserial) do |t|
      t.references(:agent, null: false, foreign_key: { to_table: :agents }, index: false)
      t.references(:operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.integer(:ownership_revision, null: false, default: 0)
      t.timestamps

      t.index(:agent_id, unique: true, name: "idx_agent_ownerships_one_resource")
      t.index(:operator_id, name: "idx_agent_ownerships_on_operator_id")
    end
    add_check_constraint(
      :agent_ownerships, "ownership_revision >= 0",
      name: "chk_agent_ownerships_revision_nonnegative",
    )

    create_table(:agent_administration_grants, id: :bigserial) do |t|
      t.references(:agent, null: false, foreign_key: { to_table: :agents }, index: false)
      t.references(:operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.timestamps

      t.index(%i(agent_id operator_id), unique: true, name: "idx_agent_admin_grants_unique")
      t.index(:operator_id, name: "idx_agent_admin_grants_on_operator_id")
    end

    create_table(:agent_delegation_grants, id: :bigserial) do |t|
      t.references(:agent, null: false, foreign_key: { to_table: :agents }, index: false)
      t.references(:operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.timestamps

      t.index(%i(agent_id operator_id), unique: true, name: "idx_agent_delegate_grants_unique")
      t.index(:operator_id, name: "idx_agent_delegate_grants_on_operator_id")
    end

    create_table(:agent_usage_grants, id: :bigserial) do |t|
      t.references(:agent, null: false, foreign_key: { to_table: :agents }, index: false)
      t.references(:operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.timestamps

      t.index(%i(agent_id operator_id), unique: true, name: "idx_agent_usage_grants_unique")
      t.index(:operator_id, name: "idx_agent_usage_grants_on_operator_id")
    end

    create_table(:agent_view_grants, id: :bigserial) do |t|
      t.references(:agent, null: false, foreign_key: { to_table: :agents }, index: false)
      t.references(:operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.timestamps

      t.index(%i(agent_id operator_id), unique: true, name: "idx_agent_view_grants_unique")
      t.index(:operator_id, name: "idx_agent_view_grants_on_operator_id")
    end

    create_table(:bureau_ownerships, id: :bigserial) do |t|
      t.references(:bureau, null: false, foreign_key: { to_table: :bureaus }, index: false)
      t.references(:operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.integer(:ownership_revision, null: false, default: 0)
      t.timestamps

      t.index(:bureau_id, unique: true, name: "idx_bureau_ownerships_one_resource")
      t.index(:operator_id, name: "idx_bureau_ownerships_on_operator_id")
    end
    add_check_constraint(
      :bureau_ownerships, "ownership_revision >= 0",
      name: "chk_bureau_ownerships_revision_nonnegative",
    )

    create_table(:bureau_administration_grants, id: :bigserial) do |t|
      t.references(:bureau, null: false, foreign_key: { to_table: :bureaus }, index: false)
      t.references(:operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.timestamps

      t.index(%i(bureau_id operator_id), unique: true, name: "idx_bureau_admin_grants_unique")
      t.index(:operator_id, name: "idx_bureau_admin_grants_on_operator_id")
    end

    create_table(:bureau_delegation_grants, id: :bigserial) do |t|
      t.references(:bureau, null: false, foreign_key: { to_table: :bureaus }, index: false)
      t.references(:operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.timestamps

      t.index(%i(bureau_id operator_id), unique: true, name: "idx_bureau_delegate_grants_unique")
      t.index(:operator_id, name: "idx_bureau_delegate_grants_on_operator_id")
    end

    create_table(:bureau_view_grants, id: :bigserial) do |t|
      t.references(:bureau, null: false, foreign_key: { to_table: :bureaus }, index: false)
      t.references(:operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.timestamps

      t.index(%i(bureau_id operator_id), unique: true, name: "idx_bureau_view_grants_unique")
      t.index(:operator_id, name: "idx_bureau_view_grants_on_operator_id")
    end

    create_table(:agent_ownership_transfer_requests, id: :bigserial) do |t|
      t.references(:agent, null: false, foreign_key: { to_table: :agents }, index: false)
      t.references(:source_operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.references(:destination_operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.string(:public_id, null: false)
      t.string(:status, null: false, default: "pending")
      t.integer(:expected_ownership_revision, null: false)
      t.datetime(:requested_at, null: false)
      t.datetime(:expires_at, null: false)
      t.datetime(:accepted_at)
      t.datetime(:rejected_at)
      t.datetime(:cancelled_at)
      t.datetime(:invalidated_at)
      t.timestamps

      t.index(:public_id, unique: true, name: "idx_agent_transfer_requests_on_public_id")
      t.index(
        :agent_id, unique: true, where: "status = 'pending'",
                   name: "idx_agent_transfer_requests_one_pending",
      )
      t.index(%i(destination_operator_id status), name: "idx_agent_transfer_requests_destination")
      t.index(%i(status expires_at), name: "idx_agent_transfer_requests_due")
    end
    add_check_constraint(
      :agent_ownership_transfer_requests,
      "source_operator_id <> destination_operator_id",
      name: "chk_agent_transfer_requests_distinct_parties",
    )
    add_check_constraint(
      :agent_ownership_transfer_requests,
      "expected_ownership_revision >= 0",
      name: "chk_agent_transfer_requests_revision_nonnegative",
    )
    add_check_constraint(
      :agent_ownership_transfer_requests,
      "requested_at < expires_at",
      name: "chk_agent_transfer_requests_expiry_after_request",
    )
    add_check_constraint(
      :agent_ownership_transfer_requests,
      "status IN ('pending', 'accepted', 'rejected', 'cancelled', 'expired', 'invalidated')",
      name: "chk_agent_transfer_requests_status",
    )

    create_table(:bureau_ownership_transfer_requests, id: :bigserial) do |t|
      t.references(:bureau, null: false, foreign_key: { to_table: :bureaus }, index: false)
      t.references(:source_operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.references(:destination_operator, null: false, foreign_key: { to_table: :operators }, index: false)
      t.string(:public_id, null: false)
      t.string(:status, null: false, default: "pending")
      t.integer(:expected_ownership_revision, null: false)
      t.datetime(:requested_at, null: false)
      t.datetime(:expires_at, null: false)
      t.datetime(:accepted_at)
      t.datetime(:rejected_at)
      t.datetime(:cancelled_at)
      t.datetime(:invalidated_at)
      t.timestamps

      t.index(:public_id, unique: true, name: "idx_bureau_transfer_requests_on_public_id")
      t.index(
        :bureau_id, unique: true, where: "status = 'pending'",
                    name: "idx_bureau_transfer_requests_one_pending",
      )
      t.index(%i(destination_operator_id status), name: "idx_bureau_transfer_requests_destination")
      t.index(%i(status expires_at), name: "idx_bureau_transfer_requests_due")
    end
    add_check_constraint(
      :bureau_ownership_transfer_requests,
      "source_operator_id <> destination_operator_id",
      name: "chk_bureau_transfer_requests_distinct_parties",
    )
    add_check_constraint(
      :bureau_ownership_transfer_requests,
      "expected_ownership_revision >= 0",
      name: "chk_bureau_transfer_requests_revision_nonnegative",
    )
    add_check_constraint(
      :bureau_ownership_transfer_requests,
      "requested_at < expires_at",
      name: "chk_bureau_transfer_requests_expiry_after_request",
    )
    add_check_constraint(
      :bureau_ownership_transfer_requests,
      "status IN ('pending', 'accepted', 'rejected', 'cancelled', 'expired', 'invalidated')",
      name: "chk_bureau_transfer_requests_status",
    )
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
