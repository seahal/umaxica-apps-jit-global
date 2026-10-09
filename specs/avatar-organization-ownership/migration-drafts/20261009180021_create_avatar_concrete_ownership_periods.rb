# frozen_string_literal: true

# Triggers here follow adr/database-trigger-usage-boundary.md: each enforces an invariant that
# spans rows or tables and must survive update_all, delete_all, TRUNCATE, and direct SQL.
class CreateAvatarConcreteOwnershipPeriods < ActiveRecord::Migration[8.2]
  OWNERS = {
    avatar_enterprise_ownership_periods: :enterprise_public_id,
    avatar_bureau_ownership_periods: :bureau_public_id,
  }.freeze
  BINDING_BASES = {
    avatar_persona_bindings: %i(avatar_enterprise_ownership_period_id avatar_enterprise_ownership_periods),
    avatar_agent_bindings: %i(avatar_bureau_ownership_period_id avatar_bureau_ownership_periods),
  }.freeze

  def up
    OWNERS.each { |table, owner_column| create_period_table(table, owner_column) }
    add_binding_bases
    create_functions
    create_triggers
  end

  def down
    drop_triggers
    execute("DROP FUNCTION avatar_ownership_timeline_check_for_avatar()")
    execute("DROP FUNCTION avatar_ownership_timeline_check()")
    execute("DROP FUNCTION assert_avatar_ownership_timeline(bigint)")
    execute("DROP FUNCTION reject_ownership_history_truncate()")
    execute("DROP FUNCTION avatar_ownership_period_guard()")
    BINDING_BASES.each do |table, (column, _periods)|
      remove_foreign_key(table, column: [column, :avatar_id])
      remove_column(table, column)
    end
    OWNERS.each_key { |table| drop_table(table) }
  end

  private

  def create_period_table(table, owner_column)
    short = table.to_s.delete_prefix("avatar_").delete_suffix("_ownership_periods")

    create_table(table) do |t|
      t.references(:avatar, null: false, index: false, foreign_key: { on_delete: :restrict })
      t.string(owner_column, null: false)
      t.timestamptz(:valid_from, null: false)
      t.timestamptz(:valid_to, null: false, default: Float::INFINITY)
      t.timestamps

      t.check_constraint("#{owner_column} ~ '[^[:space:]]'", name: "chk_avatar_#{short}_periods_owner_nonblank")
      t.check_constraint(
        "isfinite(valid_from) AND valid_from < valid_to",
        name: "chk_avatar_#{short}_periods_interval",
      )
      t.exclusion_constraint(
        "avatar_id WITH =, tstzrange(valid_from, valid_to, '[)') WITH &&",
        using: :gist, name: "excl_avatar_#{short}_periods_no_overlap",
      )
      t.index(
        :avatar_id, unique: true, where: "valid_to = 'infinity'::timestamptz",
                    name: "idx_avatar_#{short}_periods_one_current",
      )
      t.index(
        owner_column, where: "valid_to = 'infinity'::timestamptz",
                      name: "idx_avatar_#{short}_periods_current_owner",
      )
      # Target of the composite foreign keys that pin a dependent row to this period's Avatar.
      t.index(%i(id avatar_id), unique: true, name: "idx_avatar_#{short}_periods_id_avatar")
    end
  end

  def add_binding_bases
    BINDING_BASES.each do |table, (column, periods)|
      add_column(table, column, :bigint)
      add_foreign_key(
        table, periods,
        column: [column, :avatar_id], primary_key: %i(id avatar_id),
        on_delete: :restrict, validate: false,
      )
      add_index(table, column)
    end
  end

  def create_functions
    execute(<<~SQL.squish)
      CREATE FUNCTION avatar_ownership_period_guard() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'Avatar ownership periods are permanent history and cannot be deleted'
            USING ERRCODE = '23001', TABLE = TG_TABLE_NAME;
        END IF;
        IF TG_OP = 'UPDATE' THEN
          IF OLD.valid_to <> 'infinity'::timestamptz THEN
            RAISE EXCEPTION 'closed Avatar ownership period % cannot be changed', OLD.id
              USING ERRCODE = '23514', TABLE = TG_TABLE_NAME;
          END IF;
          IF NEW.valid_to = 'infinity'::timestamptz OR
             (to_jsonb(NEW) - 'valid_to' - 'updated_at') IS DISTINCT FROM
             (to_jsonb(OLD) - 'valid_to' - 'updated_at') THEN
            RAISE EXCEPTION 'open Avatar ownership period % may only be closed', OLD.id
              USING ERRCODE = '23514', TABLE = TG_TABLE_NAME;
          END IF;
        END IF;
        UPDATE avatars
           SET ownership_write_lock_counter = ownership_write_lock_counter + 1
         WHERE id = NEW.avatar_id;
        RETURN NEW;
      END;
      $$;
    SQL
    execute(<<~SQL.squish)
      CREATE FUNCTION reject_ownership_history_truncate() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'ownership history table % cannot be truncated', TG_TABLE_NAME
          USING ERRCODE = '23001', TABLE = TG_TABLE_NAME;
      END;
      $$;
    SQL
    execute(<<~SQL.squish)
      CREATE FUNCTION assert_avatar_ownership_timeline(target_avatar_id bigint) RETURNS void
      LANGUAGE plpgsql AS $$
      DECLARE
        period record;
        previous_valid_to timestamptz;
        period_count integer := 0;
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM avatars WHERE id = target_avatar_id) THEN
          RETURN;
        END IF;
        FOR period IN
          SELECT valid_from, valid_to FROM avatar_enterprise_ownership_periods
           WHERE avatar_id = target_avatar_id
          UNION ALL
          SELECT valid_from, valid_to FROM avatar_bureau_ownership_periods
           WHERE avatar_id = target_avatar_id
          ORDER BY valid_from, valid_to
        LOOP
          period_count := period_count + 1;
          IF previous_valid_to IS NOT NULL AND period.valid_from <> previous_valid_to THEN
            RAISE EXCEPTION 'Avatar % ownership periods overlap or leave a gap at %',
              target_avatar_id, period.valid_from
              USING ERRCODE = '23514', CONSTRAINT = 'avatar_ownership_timeline';
          END IF;
          previous_valid_to := period.valid_to;
        END LOOP;
        IF period_count = 0 THEN
          RAISE EXCEPTION 'Avatar % has no ownership period', target_avatar_id
            USING ERRCODE = '23514', CONSTRAINT = 'avatar_ownership_timeline';
        END IF;
        IF previous_valid_to <> 'infinity'::timestamptz THEN
          RAISE EXCEPTION 'Avatar % has no current owner', target_avatar_id
            USING ERRCODE = '23514', CONSTRAINT = 'avatar_ownership_timeline';
        END IF;
        IF EXISTS (
          SELECT 1 FROM avatar_persona_bindings b
            JOIN avatar_enterprise_ownership_periods p ON p.id = b.avatar_enterprise_ownership_period_id
           WHERE b.avatar_id = target_avatar_id AND b.revoked_at IS NULL
             AND p.valid_to <> 'infinity'::timestamptz
        ) OR EXISTS (
          SELECT 1 FROM avatar_agent_bindings b
            JOIN avatar_bureau_ownership_periods p ON p.id = b.avatar_bureau_ownership_period_id
           WHERE b.avatar_id = target_avatar_id AND b.revoked_at IS NULL
             AND p.valid_to <> 'infinity'::timestamptz
        ) THEN
          RAISE EXCEPTION 'Avatar % has an active binding granted under a closed ownership period',
            target_avatar_id
            USING ERRCODE = '23514', CONSTRAINT = 'avatar_binding_ownership_basis';
        END IF;
      END;
      $$;
    SQL
    execute(<<~SQL.squish)
      CREATE FUNCTION avatar_ownership_timeline_check() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        PERFORM assert_avatar_ownership_timeline(NEW.avatar_id);
        RETURN NULL;
      END;
      $$;
    SQL
    execute(<<~SQL.squish)
      CREATE FUNCTION avatar_ownership_timeline_check_for_avatar() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        PERFORM assert_avatar_ownership_timeline(NEW.id);
        RETURN NULL;
      END;
      $$;
    SQL
  end

  def create_triggers
    OWNERS.each_key do |table|
      execute(<<~SQL.squish)
        CREATE TRIGGER #{table}_guard
        BEFORE INSERT OR UPDATE OR DELETE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION avatar_ownership_period_guard();
      SQL
      execute(<<~SQL.squish)
        CREATE TRIGGER #{table}_truncate_guard
        BEFORE TRUNCATE ON #{table}
        FOR EACH STATEMENT EXECUTE FUNCTION reject_ownership_history_truncate();
      SQL
    end
    (OWNERS.keys + BINDING_BASES.keys).each do |table|
      execute(<<~SQL.squish)
        CREATE CONSTRAINT TRIGGER #{table}_timeline
        AFTER INSERT OR UPDATE ON #{table}
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION avatar_ownership_timeline_check();
      SQL
    end
    execute(<<~SQL.squish)
      CREATE CONSTRAINT TRIGGER avatars_ownership_timeline
      AFTER INSERT ON avatars
      DEFERRABLE INITIALLY DEFERRED
      FOR EACH ROW EXECUTE FUNCTION avatar_ownership_timeline_check_for_avatar();
    SQL
  end

  def drop_triggers
    execute("DROP TRIGGER avatars_ownership_timeline ON avatars")
    (OWNERS.keys + BINDING_BASES.keys).reverse_each do |table|
      execute("DROP TRIGGER #{table}_timeline ON #{table}")
    end
    OWNERS.keys.reverse_each do |table|
      execute("DROP TRIGGER #{table}_truncate_guard ON #{table}")
      execute("DROP TRIGGER #{table}_guard ON #{table}")
    end
  end
end
