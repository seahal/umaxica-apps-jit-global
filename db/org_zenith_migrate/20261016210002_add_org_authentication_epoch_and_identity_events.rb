# typed: false
# frozen_string_literal: true

class AddOrgAuthenticationEpochAndIdentityEvents < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  ACTOR_TABLE = :operators
  EVENT_TABLE = :identity_authentication_events
  EPOCH_CONSTRAINT = "chk_operators_authentication_epoch_nonnegative"
  EVENT_REALM_CONSTRAINT = "chk_org_identity_authentication_events_realm"
  EVENT_EPOCH_CONSTRAINT = "chk_org_identity_authentication_events_epoch_nonnegative"
  EVENT_ID_INDEX = "idx_org_identity_authentication_events_event_id"
  ACTOR_INDEX = "idx_org_identity_authentication_events_actor_epoch"

  def up
    safety_assured do
      add_column(ACTOR_TABLE, :authentication_epoch, :bigint) unless column_exists?(ACTOR_TABLE, :authentication_epoch)
      execute("UPDATE #{quote_table_name(ACTOR_TABLE)} SET authentication_epoch = 0 WHERE authentication_epoch IS NULL")
      change_column_default(ACTOR_TABLE, :authentication_epoch, from: nil, to: 0)
      change_column_null(ACTOR_TABLE, :authentication_epoch, false)
    end

    add_check_constraint(
      ACTOR_TABLE,
      "authentication_epoch >= 0",
      name: EPOCH_CONSTRAINT,
      if_not_exists: true,
      validate: false,
    )

    create_table(EVENT_TABLE, id: :bigserial, if_not_exists: true) do |t|
      t.uuid(:event_id, null: false, default: -> { "gen_random_uuid()" })
      t.string(:actor_ref, null: false)
      t.string(:realm, null: false, limit: 3)
      t.bigint(:cutoff_epoch, null: false)
      t.string(:reason, null: false, limit: 64)
      t.string(:scope, null: false, limit: 64)
      t.datetime(:committed_at, null: false)
      t.timestamps
    end

    add_index(EVENT_TABLE, :event_id, unique: true, name: EVENT_ID_INDEX, if_not_exists: true)
    add_index(EVENT_TABLE, %i(actor_ref cutoff_epoch), name: ACTOR_INDEX, if_not_exists: true)
    add_check_constraint(
      EVENT_TABLE,
      "realm = 'org'",
      name: EVENT_REALM_CONSTRAINT,
      if_not_exists: true,
      validate: false,
    )
    add_check_constraint(
      EVENT_TABLE,
      "cutoff_epoch >= 0",
      name: EVENT_EPOCH_CONSTRAINT,
      if_not_exists: true,
      validate: false,
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "authentication epoch history is forward-only"
  end
end
