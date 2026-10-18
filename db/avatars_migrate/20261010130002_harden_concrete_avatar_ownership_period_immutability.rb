# frozen_string_literal: true

class HardenConcreteAvatarOwnershipPeriodImmutability < ActiveRecord::Migration[8.2]
  FUNCTION_NAME = "guard_concrete_avatar_ownership_period_history"

  def up
    safety_assured { execute(immutability_function_sql) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Reverting this migration would restore mutable concrete ownership identities"
  end

  private

  def immutability_function_sql
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION #{FUNCTION_NAME}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'closed Avatar ownership history is immutable' USING ERRCODE = '45000';
        END IF;
        IF (to_jsonb(OLD) - 'valid_to' - 'updated_at') IS DISTINCT FROM
           (to_jsonb(NEW) - 'valid_to' - 'updated_at')
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
end
