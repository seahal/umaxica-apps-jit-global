# frozen_string_literal: true

class CreateComAuthorityRelations < ActiveRecord::Migration[8.2]
  # Keep every authority relation explicit so the schema contract can be reviewed one table at a
  # time. The resulting migration is intentionally longer than a generated abstraction.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def change
    create_table(:visitor_authority_locks, id: :bigserial) do |t|
      t.references(:visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
      t.timestamps

      t.index(:visitor_id, unique: true, name: "idx_visitor_authority_locks_on_visitor_id")
    end

    create_table(:individual_ownerships, id: :bigserial) do |t|
      t.references(:individual, null: false, foreign_key: { to_table: :individuals }, index: false)
      t.references(:visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
      t.integer(:ownership_revision, null: false, default: 0)
      t.timestamps

      t.index(:individual_id, unique: true, name: "idx_individual_ownerships_one_resource")
      t.index(:visitor_id, name: "idx_individual_ownerships_on_visitor_id")
    end
    add_check_constraint(
      :individual_ownerships, "ownership_revision >= 0",
      name: "chk_individual_ownerships_revision_nonnegative",
    )

    create_table(:individual_administration_grants, id: :bigserial) do |t|
      t.references(:individual, null: false, foreign_key: { to_table: :individuals }, index: false)
      t.references(:visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
      t.timestamps

      t.index(%i(individual_id visitor_id), unique: true, name: "idx_individual_admin_grants_unique")
      t.index(:visitor_id, name: "idx_individual_admin_grants_on_visitor_id")
    end

    create_table(:individual_delegation_grants, id: :bigserial) do |t|
      t.references(:individual, null: false, foreign_key: { to_table: :individuals }, index: false)
      t.references(:visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
      t.timestamps

      t.index(%i(individual_id visitor_id), unique: true, name: "idx_individual_delegate_grants_unique")
      t.index(:visitor_id, name: "idx_individual_delegate_grants_on_visitor_id")
    end

    create_table(:individual_usage_grants, id: :bigserial) do |t|
      t.references(:individual, null: false, foreign_key: { to_table: :individuals }, index: false)
      t.references(:visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
      t.timestamps

      t.index(%i(individual_id visitor_id), unique: true, name: "idx_individual_usage_grants_unique")
      t.index(:visitor_id, name: "idx_individual_usage_grants_on_visitor_id")
    end

    create_table(:individual_view_grants, id: :bigserial) do |t|
      t.references(:individual, null: false, foreign_key: { to_table: :individuals }, index: false)
      t.references(:visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
      t.timestamps

      t.index(%i(individual_id visitor_id), unique: true, name: "idx_individual_view_grants_unique")
      t.index(:visitor_id, name: "idx_individual_view_grants_on_visitor_id")
    end

    create_table(:company_ownerships, id: :bigserial) do |t|
      t.references(:company, null: false, foreign_key: { to_table: :companies }, index: false)
      t.references(:visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
      t.integer(:ownership_revision, null: false, default: 0)
      t.timestamps

      t.index(:company_id, unique: true, name: "idx_company_ownerships_one_resource")
      t.index(:visitor_id, name: "idx_company_ownerships_on_visitor_id")
    end
    add_check_constraint(
      :company_ownerships, "ownership_revision >= 0",
      name: "chk_company_ownerships_revision_nonnegative",
    )

    create_table(:company_administration_grants, id: :bigserial) do |t|
      t.references(:company, null: false, foreign_key: { to_table: :companies }, index: false)
      t.references(:visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
      t.timestamps

      t.index(%i(company_id visitor_id), unique: true, name: "idx_company_admin_grants_unique")
      t.index(:visitor_id, name: "idx_company_admin_grants_on_visitor_id")
    end

    create_table(:company_delegation_grants, id: :bigserial) do |t|
      t.references(:company, null: false, foreign_key: { to_table: :companies }, index: false)
      t.references(:visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
      t.timestamps

      t.index(%i(company_id visitor_id), unique: true, name: "idx_company_delegate_grants_unique")
      t.index(:visitor_id, name: "idx_company_delegate_grants_on_visitor_id")
    end

    create_table(:company_view_grants, id: :bigserial) do |t|
      t.references(:company, null: false, foreign_key: { to_table: :companies }, index: false)
      t.references(:visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
      t.timestamps

      t.index(%i(company_id visitor_id), unique: true, name: "idx_company_view_grants_unique")
      t.index(:visitor_id, name: "idx_company_view_grants_on_visitor_id")
    end

    create_table(:individual_ownership_transfer_requests, id: :bigserial) do |t|
      t.references(:individual, null: false, foreign_key: { to_table: :individuals }, index: false)
      t.references(:source_visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
      t.references(:destination_visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
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

      t.index(:public_id, unique: true, name: "idx_individual_transfer_requests_on_public_id")
      t.index(
        :individual_id, unique: true, where: "status = 'pending'",
                        name: "idx_individual_transfer_requests_one_pending",
      )
      t.index(%i(destination_visitor_id status), name: "idx_individual_transfer_requests_destination")
      t.index(%i(status expires_at), name: "idx_individual_transfer_requests_due")
    end
    add_check_constraint(
      :individual_ownership_transfer_requests,
      "source_visitor_id <> destination_visitor_id",
      name: "chk_individual_transfer_requests_distinct_parties",
    )
    add_check_constraint(
      :individual_ownership_transfer_requests,
      "expected_ownership_revision >= 0",
      name: "chk_individual_transfer_requests_revision_nonnegative",
    )
    add_check_constraint(
      :individual_ownership_transfer_requests,
      "requested_at < expires_at",
      name: "chk_individual_transfer_requests_expiry_after_request",
    )
    add_check_constraint(
      :individual_ownership_transfer_requests,
      "status IN ('pending', 'accepted', 'rejected', 'cancelled', 'expired', 'invalidated')",
      name: "chk_individual_transfer_requests_status",
    )

    create_table(:company_ownership_transfer_requests, id: :bigserial) do |t|
      t.references(:company, null: false, foreign_key: { to_table: :companies }, index: false)
      t.references(:source_visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
      t.references(:destination_visitor, null: false, foreign_key: { to_table: :visitors }, index: false)
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

      t.index(:public_id, unique: true, name: "idx_company_transfer_requests_on_public_id")
      t.index(
        :company_id, unique: true, where: "status = 'pending'",
                     name: "idx_company_transfer_requests_one_pending",
      )
      t.index(%i(destination_visitor_id status), name: "idx_company_transfer_requests_destination")
      t.index(%i(status expires_at), name: "idx_company_transfer_requests_due")
    end
    add_check_constraint(
      :company_ownership_transfer_requests,
      "source_visitor_id <> destination_visitor_id",
      name: "chk_company_transfer_requests_distinct_parties",
    )
    add_check_constraint(
      :company_ownership_transfer_requests,
      "expected_ownership_revision >= 0",
      name: "chk_company_transfer_requests_revision_nonnegative",
    )
    add_check_constraint(
      :company_ownership_transfer_requests,
      "requested_at < expires_at",
      name: "chk_company_transfer_requests_expiry_after_request",
    )
    add_check_constraint(
      :company_ownership_transfer_requests,
      "status IN ('pending', 'accepted', 'rejected', 'cancelled', 'expired', 'invalidated')",
      name: "chk_company_transfer_requests_status",
    )
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
