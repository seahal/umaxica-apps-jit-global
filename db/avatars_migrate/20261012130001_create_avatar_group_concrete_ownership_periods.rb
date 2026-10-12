# frozen_string_literal: true

class CreateAvatarGroupConcreteOwnershipPeriods < ActiveRecord::Migration[8.2]
  TABLE_NAME = :avatar_group_concrete_ownership_periods
  INTEGRITY_FUNCTION = "enforce_avatar_group_concrete_ownership_period_integrity"
  IMMUTABILITY_FUNCTION = "guard_avatar_group_concrete_ownership_period_history"
  TRUNCATE_FUNCTION = "reject_avatar_group_concrete_ownership_period_truncate"

  def up
    enable_extension("btree_gist") unless extension_enabled?("btree_gist")
    create_period_table
    add_period_constraints
    add_period_indexes
    create_period_triggers
  end

  def down
    safety_assured do
      execute("DROP TRIGGER avatar_group_concrete_ownership_periods_no_truncate ON #{TABLE_NAME}")
      execute("DROP TRIGGER avatar_group_concrete_ownership_periods_immutability ON #{TABLE_NAME}")
      execute("DROP TRIGGER avatar_group_concrete_ownership_periods_integrity ON #{TABLE_NAME}")
      execute("DROP FUNCTION #{TRUNCATE_FUNCTION}()")
      execute("DROP FUNCTION #{IMMUTABILITY_FUNCTION}()")
      execute("DROP FUNCTION #{INTEGRITY_FUNCTION}()")
    end
    remove_exclusion_constraint(TABLE_NAME, name: "excl_avatar_group_concrete_ownership_periods_no_overlap")
    remove_index(TABLE_NAME, name: "idx_avatar_group_concrete_ownership_periods_current_owner")
    remove_index(TABLE_NAME, name: "idx_avatar_group_concrete_ownership_periods_one_current")
    remove_index(TABLE_NAME, name: "idx_avatar_group_concrete_ownership_periods_group")
    remove_check_constraint(TABLE_NAME, name: "chk_avatar_group_concrete_ownership_periods_valid_interval")
    remove_check_constraint(TABLE_NAME, name: "chk_avatar_group_concrete_ownership_periods_owner_collective")
    remove_check_constraint(TABLE_NAME, name: "chk_avatar_group_concrete_ownership_periods_owner_surface")
    drop_table(TABLE_NAME)
  end

  private

  def create_period_table
    create_table(TABLE_NAME) do |t|
      t.references(:avatar_group, null: false, index: false, foreign_key: { on_delete: :restrict })
      t.string(:owner_surface, null: false)
      t.string(:owner_collective_public_id, null: false, limit: 255)
      t.datetime(:valid_from, null: false)
      t.datetime(:valid_to, null: false, default: Float::INFINITY)
      t.timestamps
    end
  end

  def add_period_constraints
    add_check_constraint(
      TABLE_NAME,
      "owner_surface IN ('app', 'org')",
      name: "chk_avatar_group_concrete_ownership_periods_owner_surface",
    )
    add_check_constraint(
      TABLE_NAME,
      "owner_collective_public_id <> '' AND owner_collective_public_id ~ '[^[:space:]]'",
      name: "chk_avatar_group_concrete_ownership_periods_owner_collective",
    )
    add_check_constraint(
      TABLE_NAME,
      "isfinite(valid_from) AND valid_from < valid_to",
      name: "chk_avatar_group_concrete_ownership_periods_valid_interval",
    )
    add_exclusion_constraint(
      TABLE_NAME,
      "avatar_group_id WITH =, tstzrange(valid_from, valid_to, '[)') WITH &&",
      using: :gist,
      name: "excl_avatar_group_concrete_ownership_periods_no_overlap",
    )
  end

  def add_period_indexes
    add_index(TABLE_NAME, :avatar_group_id, name: "idx_avatar_group_concrete_ownership_periods_group")
    add_index(
      TABLE_NAME,
      :avatar_group_id,
      unique: true,
      where: "valid_to = 'infinity'::timestamp with time zone",
      name: "idx_avatar_group_concrete_ownership_periods_one_current",
    )
    add_index(
      TABLE_NAME,
      %i(owner_surface owner_collective_public_id),
      where: "valid_to = 'infinity'::timestamp with time zone",
      name: "idx_avatar_group_concrete_ownership_periods_current_owner",
    )
  end

  def create_period_triggers
    safety_assured do
      execute(integrity_function_sql)
      execute(immutability_function_sql)
      execute(truncate_function_sql)
      execute(<<~SQL.squish)
        CREATE CONSTRAINT TRIGGER avatar_group_concrete_ownership_periods_integrity
        AFTER INSERT OR UPDATE OR DELETE ON #{TABLE_NAME}
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION #{INTEGRITY_FUNCTION}()
      SQL
      execute(<<~SQL.squish)
        CREATE TRIGGER avatar_group_concrete_ownership_periods_immutability
        BEFORE UPDATE OR DELETE ON #{TABLE_NAME}
        FOR EACH ROW EXECUTE FUNCTION #{IMMUTABILITY_FUNCTION}()
      SQL
      execute(<<~SQL.squish)
        CREATE TRIGGER avatar_group_concrete_ownership_periods_no_truncate
        BEFORE TRUNCATE ON #{TABLE_NAME}
        FOR EACH STATEMENT EXECUTE FUNCTION #{TRUNCATE_FUNCTION}()
      SQL
    end
  end

  def integrity_function_sql
    <<~SQL.squish
      CREATE FUNCTION #{INTEGRITY_FUNCTION}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        target_group_id bigint := COALESCE(NEW.avatar_group_id, OLD.avatar_group_id);
        group_created_at timestamptz;
        period_count integer;
        current_count integer;
        first_valid_from timestamptz;
        has_gap boolean;
      BEGIN
        SELECT created_at INTO group_created_at
          FROM avatar_groups
         WHERE id = target_group_id
         FOR UPDATE;
        IF NOT FOUND THEN
          RAISE EXCEPTION 'avatar group % does not exist for concrete ownership integrity', target_group_id
            USING ERRCODE = '23503';
        END IF;

        WITH ordered AS (
          SELECT valid_from, valid_to,
                 lag(valid_to) OVER (ORDER BY valid_from, valid_to) AS previous_to
            FROM avatar_group_concrete_ownership_periods
           WHERE avatar_group_id = target_group_id
        )
        SELECT count(*), count(*) FILTER (WHERE valid_to = 'infinity'::timestamptz),
               min(valid_from),
               bool_or(previous_to IS NOT NULL AND valid_from <> previous_to)
          INTO period_count, current_count, first_valid_from, has_gap
          FROM ordered;

        IF period_count = 0 OR current_count <> 1 THEN
          RAISE EXCEPTION 'avatar group % must have exactly one current concrete ownership period', target_group_id
            USING ERRCODE = '23514';
        END IF;
        IF first_valid_from <> group_created_at OR COALESCE(has_gap, false) THEN
          RAISE EXCEPTION 'avatar group % concrete ownership periods must form one uninterrupted chain', target_group_id
            USING ERRCODE = '23514';
        END IF;

        RETURN NULL;
      END;
      $$;
    SQL
  end

  def immutability_function_sql
    <<~SQL.squish
      CREATE FUNCTION #{IMMUTABILITY_FUNCTION}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'closed Avatar Group ownership history is immutable'
            USING ERRCODE = '45000';
        END IF;
        IF OLD.avatar_group_id IS DISTINCT FROM NEW.avatar_group_id
           OR OLD.owner_surface IS DISTINCT FROM NEW.owner_surface
           OR OLD.owner_collective_public_id IS DISTINCT FROM NEW.owner_collective_public_id
           OR OLD.valid_from IS DISTINCT FROM NEW.valid_from
           OR OLD.valid_to <> 'infinity'::timestamptz
           OR NEW.valid_to <= NEW.valid_from
           OR NEW.valid_to = 'infinity'::timestamptz THEN
          RAISE EXCEPTION 'Avatar Group ownership history may only close its current period once'
            USING ERRCODE = '45000';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end

  def truncate_function_sql
    <<~SQL.squish
      CREATE FUNCTION #{TRUNCATE_FUNCTION}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'Avatar Group ownership history cannot be truncated' USING ERRCODE = '45000';
      END;
      $$;
    SQL
  end
end
