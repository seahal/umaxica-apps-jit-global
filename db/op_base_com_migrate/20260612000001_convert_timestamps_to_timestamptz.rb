# typed: false
# frozen_string_literal: true

class ConvertTimestampsToTimestamptz < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute(<<~'SQL'.squish)
        DO $$
        DECLARE
          rec RECORD;
        BEGIN
          FOR rec IN
            SELECT table_name, column_name
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND data_type = 'timestamp without time zone'
          LOOP
            EXECUTE format(
              'ALTER TABLE %I ALTER COLUMN %I TYPE timestamptz USING %I AT TIME ZONE ''UTC''',
              rec.table_name, rec.column_name, rec.column_name
            );
          END LOOP;
        END;
        $$;
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Cannot safely reverse: original column types were not recorded"
  end
end
