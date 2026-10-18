# frozen_string_literal: true

class ProtectOrgPreferencePublicId < ActiveRecord::Migration[8.2]
  def up
    # The named three-table exception is recorded in adr/database-trigger-usage-boundary.md.
    # OLD/NEW comparison needs a trigger; this function has no secondary writes or locks.
    safety_assured do
      execute(<<~SQL.squish)
        CREATE FUNCTION prevent_org_preference_public_id_mutation() RETURNS trigger
        LANGUAGE plpgsql AS $$
        BEGIN
          IF NEW.public_id IS DISTINCT FROM OLD.public_id THEN
            RAISE EXCEPTION 'preference public identity cannot be changed'
              USING ERRCODE = '23514', CONSTRAINT = 'org_preferences_public_id_immutable';
          END IF;
          RETURN NEW;
        END;
        $$;
      SQL
      execute(<<~SQL.squish)
        CREATE TRIGGER org_preferences_public_id_immutability
        BEFORE UPDATE OF public_id ON org_preferences
        FOR EACH ROW EXECUTE FUNCTION prevent_org_preference_public_id_mutation();
      SQL
    end
  end

  def down
    safety_assured do
      execute("DROP TRIGGER org_preferences_public_id_immutability ON org_preferences")
      execute("DROP FUNCTION prevent_org_preference_public_id_mutation()")
    end
  end
end
