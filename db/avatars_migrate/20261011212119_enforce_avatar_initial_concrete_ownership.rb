# frozen_string_literal: true

class EnforceAvatarInitialConcreteOwnership < ActiveRecord::Migration[8.2]
  FUNCTION = "enforce_avatar_initial_concrete_owner"
  TRIGGER = "avatar_initial_concrete_owner_required"

  def up
    safety_assured do
      execute(function_sql)
      execute(<<~SQL.squish)
        CREATE CONSTRAINT TRIGGER #{TRIGGER}
        AFTER INSERT ON avatars
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
        EXECUTE FUNCTION #{FUNCTION}();
      SQL
    end
  end

  def down
    safety_assured do
      execute("DROP TRIGGER IF EXISTS #{TRIGGER} ON avatars")
      execute("DROP FUNCTION IF EXISTS #{FUNCTION}()")
    end
  end

  private

  # The ownership-period triggers protect the chain after period writes. This separate
  # deferred INSERT guard closes the creation boundary: an Avatar cannot commit before
  # its concrete Enterprise or Bureau period exists in the same Avatar transaction.
  # It has no writes, notifications, or owner-selection behavior.
  def function_sql
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION #{FUNCTION}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        period_count integer;
        current_count integer;
        first_valid_from timestamptz;
      BEGIN
        WITH periods AS (
          SELECT valid_from, valid_to
            FROM avatar_enterprise_ownership_periods
           WHERE avatar_id = NEW.id
          UNION ALL
          SELECT valid_from, valid_to
            FROM avatar_bureau_ownership_periods
           WHERE avatar_id = NEW.id
        )
        SELECT count(*), count(*) FILTER (WHERE valid_to = 'infinity'::timestamptz), min(valid_from)
          INTO period_count, current_count, first_valid_from
          FROM periods;

        IF period_count = 0 OR current_count <> 1 OR first_valid_from IS DISTINCT FROM NEW.created_at THEN
          RAISE EXCEPTION 'Avatar % must be created with one concrete ownership period', NEW.id
            USING ERRCODE = '23514', CONSTRAINT = '#{TRIGGER}';
        END IF;

        RETURN NULL;
      END;
      $$;
    SQL
  end
end
