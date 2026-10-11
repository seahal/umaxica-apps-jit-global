# frozen_string_literal: true

class CreateConcreteAvatarOwnershipPeriods < ActiveRecord::Migration[8.2]
  ENTERPRISE_TABLE = :avatar_enterprise_ownership_periods
  BUREAU_TABLE = :avatar_bureau_ownership_periods
  INTEGRITY_FUNCTION = "enforce_concrete_avatar_ownership_period_integrity"
  IMMUTABILITY_FUNCTION = "guard_concrete_avatar_ownership_period_history"
  TRUNCATE_FUNCTION = "reject_concrete_avatar_ownership_period_truncate"

  def up
    enable_extension("btree_gist") unless extension_enabled?("btree_gist")

    safety_assured do
      add_column(:avatars, :ownership_integrity_version, :bigint, null: false, default: 0)
    end

    create_period_table(ENTERPRISE_TABLE, :enterprise_public_id)
    create_period_table(BUREAU_TABLE, :bureau_public_id)
    add_period_constraints(ENTERPRISE_TABLE, :enterprise_public_id, "excl_avatar_enterprise_ownership_periods_non_overlapping")
    add_period_constraints(BUREAU_TABLE, :bureau_public_id, "excl_avatar_bureau_ownership_periods_non_overlapping")

    safety_assured do
      execute(integrity_function_sql)
      execute(immutability_function_sql)
      execute(truncate_function_sql)
      attach_period_triggers(ENTERPRISE_TABLE, "avatar_enterprise_ownership_periods")
      attach_period_triggers(BUREAU_TABLE, "avatar_bureau_ownership_periods")
    end
  end

  def down
    safety_assured do
      detach_period_triggers(ENTERPRISE_TABLE, "avatar_enterprise_ownership_periods")
      detach_period_triggers(BUREAU_TABLE, "avatar_bureau_ownership_periods")
      execute("DROP FUNCTION IF EXISTS #{INTEGRITY_FUNCTION}()")
      execute("DROP FUNCTION IF EXISTS #{IMMUTABILITY_FUNCTION}()")
      execute("DROP FUNCTION IF EXISTS #{TRUNCATE_FUNCTION}()")
    end

    drop_table(BUREAU_TABLE)
    drop_table(ENTERPRISE_TABLE)
    remove_column(:avatars, :ownership_integrity_version)
  end

  private

  def create_period_table(table, owner_column)
    create_table(table) do |t|
      t.references(:avatar, null: false, index: false, foreign_key: { on_delete: :restrict })
      t.string(owner_column, null: false, limit: 255)
      t.string(:transferred_by_actor_public_id, limit: 255)
      t.datetime(:valid_from, null: false)
      t.datetime(:valid_to, null: false, default: Float::INFINITY)
      t.timestamps
    end

    add_index(table, :avatar_id, name: "idx_#{table}_avatar_all")
    add_index(
      table,
      :avatar_id,
      unique: true,
      where: "valid_to = 'infinity'::timestamp with time zone",
      name: "idx_#{table}_current_avatar",
    )
    add_index(table, owner_column, name: "idx_#{table}_owner")
  end

  def add_period_constraints(table, owner_column, exclusion_name)
    add_check_constraint(table, "valid_from < valid_to", name: "chk_#{table}_strict_interval", validate: false)
    add_check_constraint(table, "#{owner_column} <> '' AND #{owner_column} ~ '[^[:space:]]'", name: "chk_#{table}_owner_nonblank")
    safety_assured do
      add_exclusion_constraint(
        table,
        "avatar_id WITH =, tstzrange(valid_from, valid_to, '[)') WITH &&",
        using: :gist,
        name: exclusion_name,
      )
    end
  end

  # Keep the invariant in one PostgreSQL function so its deferred check is atomic.
  # rubocop:disable Metrics/MethodLength
  def integrity_function_sql
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION #{INTEGRITY_FUNCTION}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        target_avatar_id bigint := COALESCE(NEW.avatar_id, OLD.avatar_id);
        avatar_created_at timestamptz;
        period_count integer;
        current_count integer;
        first_valid_from timestamptz;
        has_gap boolean;
        has_cross_family_overlap boolean;
      BEGIN
        UPDATE avatars
           SET ownership_integrity_version = ownership_integrity_version + 1
         WHERE id = target_avatar_id;
        IF NOT FOUND THEN
          RAISE EXCEPTION 'avatar % does not exist for ownership period integrity', target_avatar_id
            USING ERRCODE = '23503';
        END IF;

        SELECT created_at INTO avatar_created_at FROM avatars WHERE id = target_avatar_id;

        WITH periods AS (
          SELECT valid_from, valid_to FROM avatar_enterprise_ownership_periods WHERE avatar_id = target_avatar_id
          UNION ALL
          SELECT valid_from, valid_to FROM avatar_bureau_ownership_periods WHERE avatar_id = target_avatar_id
        ), ordered AS (
          SELECT valid_from, valid_to, lag(valid_to) OVER (ORDER BY valid_from, valid_to) AS previous_to
          FROM periods
        )
        SELECT count(*), count(*) FILTER (WHERE valid_to = 'infinity'::timestamptz),
               min(valid_from), bool_or(previous_to IS NOT NULL AND valid_from <> previous_to)
          INTO period_count, current_count, first_valid_from, has_gap
          FROM ordered;

        IF period_count = 0 OR current_count <> 1 THEN
          RAISE EXCEPTION 'avatar % must have exactly one current ownership period', target_avatar_id
            USING ERRCODE = '23514';
        END IF;
        IF first_valid_from <> avatar_created_at OR COALESCE(has_gap, false) THEN
          RAISE EXCEPTION 'avatar % ownership periods must form one uninterrupted chain', target_avatar_id
            USING ERRCODE = '23514';
        END IF;

        SELECT EXISTS (
          SELECT 1
            FROM avatar_enterprise_ownership_periods enterprise_period
            JOIN avatar_bureau_ownership_periods bureau_period
              ON bureau_period.avatar_id = enterprise_period.avatar_id
           WHERE enterprise_period.avatar_id = target_avatar_id
             AND tstzrange(enterprise_period.valid_from, enterprise_period.valid_to, '[)') &&
                 tstzrange(bureau_period.valid_from, bureau_period.valid_to, '[)')
        ) INTO has_cross_family_overlap;
        IF has_cross_family_overlap THEN
          RAISE EXCEPTION 'avatar % has overlapping concrete ownership periods', target_avatar_id
            USING ERRCODE = '23P01';
        END IF;

        RETURN NULL;
      END;
      $$;
    SQL
  end
  # rubocop:enable Metrics/MethodLength

  def immutability_function_sql
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION #{IMMUTABILITY_FUNCTION}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'closed Avatar ownership history is immutable' USING ERRCODE = '45000';
        END IF;
        IF OLD.avatar_id IS DISTINCT FROM NEW.avatar_id
           OR OLD.valid_from IS DISTINCT FROM NEW.valid_from
           OR OLD.transferred_by_actor_public_id IS DISTINCT FROM NEW.transferred_by_actor_public_id
           OR OLD.valid_to <> 'infinity'::timestamptz
           OR NEW.valid_to <= NEW.valid_from
           OR NEW.valid_to = 'infinity'::timestamptz THEN
          RAISE EXCEPTION 'Avatar ownership history may only close its current period once'
            USING ERRCODE = '45000';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end

  def truncate_function_sql
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION #{TRUNCATE_FUNCTION}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'Avatar ownership history cannot be truncated' USING ERRCODE = '45000';
      END;
      $$;
    SQL
  end

  def attach_period_triggers(table, prefix)
    execute(<<~SQL.squish)
      CREATE CONSTRAINT TRIGGER #{prefix}_integrity
      AFTER INSERT OR UPDATE OR DELETE ON #{table}
      DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
      EXECUTE FUNCTION #{INTEGRITY_FUNCTION}();
      CREATE TRIGGER #{prefix}_immutability
      BEFORE UPDATE OR DELETE ON #{table}
      FOR EACH ROW EXECUTE FUNCTION #{IMMUTABILITY_FUNCTION}();
      CREATE TRIGGER #{prefix}_no_truncate
      BEFORE TRUNCATE ON #{table}
      FOR EACH STATEMENT EXECUTE FUNCTION #{TRUNCATE_FUNCTION}();
    SQL
  end

  def detach_period_triggers(table, prefix)
    execute(<<~SQL.squish)
      DROP TRIGGER IF EXISTS #{prefix}_no_truncate ON #{table};
      DROP TRIGGER IF EXISTS #{prefix}_immutability ON #{table};
      DROP TRIGGER IF EXISTS #{prefix}_integrity ON #{table};
    SQL
  end
end
