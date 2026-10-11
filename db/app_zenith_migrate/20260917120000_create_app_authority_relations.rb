# frozen_string_literal: true

class CreateAppAuthorityRelations < ActiveRecord::Migration[8.2]
  # Keep every authority relation explicit so the schema contract can be reviewed one table at a
  # time. The resulting migration is intentionally longer than a generated abstraction.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def change
    # The principal models and the RP/resource models retain different
    # semantic Active Record bases, but both inherit the canonical app_zenith
    # writer boundary. The surface-local lock row gives authority writes one
    # stable lock target. Every quota-affecting app operation must acquire
    # this row before reading ownership state.
    create_table(:client_authority_locks, id: :bigserial) do |t|
      t.references(:client, null: false, foreign_key: { to_table: :clients }, index: false)
      t.timestamps

      t.index(:client_id, unique: true, name: "idx_client_authority_locks_on_client_id")
    end

    create_table(:client_persona_ownerships, id: :bigserial) do |t|
      t.references(:client_persona, null: false, foreign_key: { to_table: :personas }, index: false)
      t.references(:client, null: false, foreign_key: { to_table: :clients }, index: false)
      t.integer(:ownership_revision, null: false, default: 0)
      t.timestamps

      t.index(:client_persona_id, unique: true, name: "idx_client_persona_ownerships_one_resource")
      t.index(:client_id, name: "idx_client_persona_ownerships_on_client_id")
    end
    add_check_constraint(
      :client_persona_ownerships, "ownership_revision >= 0",
      name: "chk_client_persona_ownerships_revision_nonnegative",
    )

    create_table(:client_persona_administration_grants, id: :bigserial) do |t|
      t.references(:client_persona, null: false, foreign_key: { to_table: :personas }, index: false)
      t.references(:client, null: false, foreign_key: { to_table: :clients }, index: false)
      t.timestamps

      t.index(
        %i(client_persona_id client_id), unique: true,
                                         name: "idx_client_persona_admin_grants_unique",
      )
      t.index(:client_id, name: "idx_client_persona_admin_grants_on_client_id")
    end

    create_table(:client_persona_delegation_grants, id: :bigserial) do |t|
      t.references(:client_persona, null: false, foreign_key: { to_table: :personas }, index: false)
      t.references(:client, null: false, foreign_key: { to_table: :clients }, index: false)
      t.timestamps

      t.index(
        %i(client_persona_id client_id), unique: true,
                                         name: "idx_client_persona_delegate_grants_unique",
      )
      t.index(:client_id, name: "idx_client_persona_delegate_grants_on_client_id")
    end

    create_table(:client_persona_usage_grants, id: :bigserial) do |t|
      t.references(:client_persona, null: false, foreign_key: { to_table: :personas }, index: false)
      t.references(:client, null: false, foreign_key: { to_table: :clients }, index: false)
      t.timestamps

      t.index(
        %i(client_persona_id client_id), unique: true,
                                         name: "idx_client_persona_usage_grants_unique",
      )
      t.index(:client_id, name: "idx_client_persona_usage_grants_on_client_id")
    end

    create_table(:client_persona_view_grants, id: :bigserial) do |t|
      t.references(:client_persona, null: false, foreign_key: { to_table: :personas }, index: false)
      t.references(:client, null: false, foreign_key: { to_table: :clients }, index: false)
      t.timestamps

      t.index(
        %i(client_persona_id client_id), unique: true,
                                         name: "idx_client_persona_view_grants_unique",
      )
      t.index(:client_id, name: "idx_client_persona_view_grants_on_client_id")
    end

    create_table(:enterprise_ownerships, id: :bigserial) do |t|
      t.references(:enterprise, null: false, foreign_key: { to_table: :enterprises }, index: false)
      t.references(:client, null: false, foreign_key: { to_table: :clients }, index: false)
      t.integer(:ownership_revision, null: false, default: 0)
      t.timestamps

      t.index(:enterprise_id, unique: true, name: "idx_enterprise_ownerships_one_resource")
      t.index(:client_id, name: "idx_enterprise_ownerships_on_client_id")
    end
    add_check_constraint(
      :enterprise_ownerships, "ownership_revision >= 0",
      name: "chk_enterprise_ownerships_revision_nonnegative",
    )

    create_table(:enterprise_administration_grants, id: :bigserial) do |t|
      t.references(:enterprise, null: false, foreign_key: { to_table: :enterprises }, index: false)
      t.references(:client, null: false, foreign_key: { to_table: :clients }, index: false)
      t.timestamps

      t.index(%i(enterprise_id client_id), unique: true, name: "idx_enterprise_admin_grants_unique")
      t.index(:client_id, name: "idx_enterprise_admin_grants_on_client_id")
    end

    create_table(:enterprise_delegation_grants, id: :bigserial) do |t|
      t.references(:enterprise, null: false, foreign_key: { to_table: :enterprises }, index: false)
      t.references(:client, null: false, foreign_key: { to_table: :clients }, index: false)
      t.timestamps

      t.index(%i(enterprise_id client_id), unique: true, name: "idx_enterprise_delegate_grants_unique")
      t.index(:client_id, name: "idx_enterprise_delegate_grants_on_client_id")
    end

    create_table(:enterprise_view_grants, id: :bigserial) do |t|
      t.references(:enterprise, null: false, foreign_key: { to_table: :enterprises }, index: false)
      t.references(:client, null: false, foreign_key: { to_table: :clients }, index: false)
      t.timestamps

      t.index(%i(enterprise_id client_id), unique: true, name: "idx_enterprise_view_grants_unique")
      t.index(:client_id, name: "idx_enterprise_view_grants_on_client_id")
    end

    create_table(:client_persona_ownership_transfer_requests, id: :bigserial) do |t|
      t.references(:client_persona, null: false, foreign_key: { to_table: :personas }, index: false)
      t.references(:source_client, null: false, foreign_key: { to_table: :clients }, index: false)
      t.references(:destination_client, null: false, foreign_key: { to_table: :clients }, index: false)
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

      t.index(:public_id, unique: true, name: "idx_client_persona_transfer_requests_on_public_id")
      t.index(
        :client_persona_id, unique: true, where: "status = 'pending'",
                            name: "idx_client_persona_transfer_requests_one_pending",
      )
      t.index(%i(destination_client_id status), name: "idx_client_persona_transfer_requests_destination")
      t.index(%i(status expires_at), name: "idx_client_persona_transfer_requests_due")
    end
    add_check_constraint(
      :client_persona_ownership_transfer_requests,
      "source_client_id <> destination_client_id",
      name: "chk_client_persona_transfer_requests_distinct_parties",
    )
    add_check_constraint(
      :client_persona_ownership_transfer_requests,
      "expected_ownership_revision >= 0",
      name: "chk_client_persona_transfer_requests_revision_nonnegative",
    )
    add_check_constraint(
      :client_persona_ownership_transfer_requests,
      "requested_at < expires_at",
      name: "chk_client_persona_transfer_requests_expiry_after_request",
    )
    add_check_constraint(
      :client_persona_ownership_transfer_requests,
      "status IN ('pending', 'accepted', 'rejected', 'cancelled', 'expired', 'invalidated')",
      name: "chk_client_persona_transfer_requests_status",
    )

    create_table(:enterprise_ownership_transfer_requests, id: :bigserial) do |t|
      t.references(:enterprise, null: false, foreign_key: { to_table: :enterprises }, index: false)
      t.references(:source_client, null: false, foreign_key: { to_table: :clients }, index: false)
      t.references(:destination_client, null: false, foreign_key: { to_table: :clients }, index: false)
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

      t.index(:public_id, unique: true, name: "idx_enterprise_transfer_requests_on_public_id")
      t.index(
        :enterprise_id, unique: true, where: "status = 'pending'",
                        name: "idx_enterprise_transfer_requests_one_pending",
      )
      t.index(%i(destination_client_id status), name: "idx_enterprise_transfer_requests_destination")
      t.index(%i(status expires_at), name: "idx_enterprise_transfer_requests_due")
    end
    add_check_constraint(
      :enterprise_ownership_transfer_requests,
      "source_client_id <> destination_client_id",
      name: "chk_enterprise_transfer_requests_distinct_parties",
    )
    add_check_constraint(
      :enterprise_ownership_transfer_requests,
      "expected_ownership_revision >= 0",
      name: "chk_enterprise_transfer_requests_revision_nonnegative",
    )
    add_check_constraint(
      :enterprise_ownership_transfer_requests,
      "requested_at < expires_at",
      name: "chk_enterprise_transfer_requests_expiry_after_request",
    )
    add_check_constraint(
      :enterprise_ownership_transfer_requests,
      "status IN ('pending', 'accepted', 'rejected', 'cancelled', 'expired', 'invalidated')",
      name: "chk_enterprise_transfer_requests_status",
    )
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
