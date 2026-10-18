# frozen_string_literal: true

class AddAvatarOwnershipCutoverBarrier < ActiveRecord::Migration[8.2]
  LEGACY_TABLES = %w(
    avatar_ownership_periods
    avatar_ownership_transfers
    avatar_group_ownership_periods
  ).freeze
  LEGACY_WRITE_FUNCTION = "prevent_avatar_legacy_owner_write"
  CUTOVER_MUTATION_FUNCTION = "prevent_avatar_ownership_cutover_mutation"

  def up
    create_cutover_table
    safety_assured do
      execute(legacy_write_function_sql)
      execute(cutover_mutation_function_sql)
      create_legacy_write_triggers
      create_cutover_mutation_triggers
    end
  end

  def down
    safety_assured do
      drop_cutover_mutation_triggers
      drop_legacy_write_triggers
      execute("DROP FUNCTION #{CUTOVER_MUTATION_FUNCTION}()")
      execute("DROP FUNCTION #{LEGACY_WRITE_FUNCTION}()")
    end
    remove_index(:avatar_ownership_cutovers, column: :id)
    remove_check_constraint(:avatar_ownership_cutovers, name: "chk_avatar_ownership_cutovers_singleton")
    drop_table(:avatar_ownership_cutovers)
  end

  private

  def create_cutover_table
    create_table(:avatar_ownership_cutovers, id: false) do |t|
      t.bigint(:id, null: false)
      t.datetime(:cutover_at, null: false)
      t.timestamps
    end
    add_check_constraint(
      :avatar_ownership_cutovers,
      "id = 1 AND isfinite(cutover_at)",
      name: "chk_avatar_ownership_cutovers_singleton",
    )
    add_index(:avatar_ownership_cutovers, :id, unique: true)
  end

  def create_legacy_write_triggers
    LEGACY_TABLES.each do |table|
      execute(<<~SQL.squish)
        CREATE TRIGGER #{table}_legacy_write_barrier
        BEFORE INSERT OR UPDATE OR DELETE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION #{LEGACY_WRITE_FUNCTION}();
      SQL
      execute(<<~SQL.squish)
        CREATE TRIGGER #{table}_legacy_truncate_barrier
        BEFORE TRUNCATE ON #{table}
        FOR EACH STATEMENT EXECUTE FUNCTION #{LEGACY_WRITE_FUNCTION}();
      SQL
    end
  end

  def create_cutover_mutation_triggers
    execute(<<~SQL.squish)
      CREATE TRIGGER avatar_ownership_cutovers_immutability
      BEFORE UPDATE OR DELETE ON avatar_ownership_cutovers
      FOR EACH ROW EXECUTE FUNCTION #{CUTOVER_MUTATION_FUNCTION}();
    SQL
    execute(<<~SQL.squish)
      CREATE TRIGGER avatar_ownership_cutovers_no_truncate
      BEFORE TRUNCATE ON avatar_ownership_cutovers
      FOR EACH STATEMENT EXECUTE FUNCTION #{CUTOVER_MUTATION_FUNCTION}();
    SQL
  end

  def drop_legacy_write_triggers
    LEGACY_TABLES.each do |table|
      execute("DROP TRIGGER #{table}_legacy_truncate_barrier ON #{table}")
      execute("DROP TRIGGER #{table}_legacy_write_barrier ON #{table}")
    end
  end

  def drop_cutover_mutation_triggers
    execute("DROP TRIGGER avatar_ownership_cutovers_no_truncate ON avatar_ownership_cutovers")
    execute("DROP TRIGGER avatar_ownership_cutovers_immutability ON avatar_ownership_cutovers")
  end

  def legacy_write_function_sql
    <<~SQL.squish
      CREATE FUNCTION #{LEGACY_WRITE_FUNCTION}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF EXISTS (SELECT 1 FROM avatar_ownership_cutovers WHERE id = 1) THEN
          RAISE EXCEPTION 'legacy Avatar ownership writes are disabled after cutover'
            USING ERRCODE = '55006', CONSTRAINT = 'avatar_legacy_owner_write_barrier';
        END IF;
        IF TG_LEVEL = 'STATEMENT' THEN
          RETURN NULL;
        END IF;
        RETURN COALESCE(NEW, OLD);
      END;
      $$;
    SQL
  end

  def cutover_mutation_function_sql
    <<~SQL.squish
      CREATE FUNCTION #{CUTOVER_MUTATION_FUNCTION}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'Avatar ownership cutover marker is immutable'
          USING ERRCODE = '55006', CONSTRAINT = 'avatar_ownership_cutover_immutable';
      END;
      $$;
    SQL
  end
end
