# frozen_string_literal: true

class ProtectOperatorTelephonePublicId < ActiveRecord::Migration[8.2]
  def up
    # Explicit one-table approval: adr/database-trigger-usage-boundary.md.
    # The row-local rejection takes no additional locks or writes; migration DDL uses
    # the repository's bounded lock timeout. CHECK cannot compare OLD with NEW.
    safety_assured do
      execute(<<~SQL.squish)
        CREATE FUNCTION prevent_operator_telephone_public_id_mutation() RETURNS trigger
        LANGUAGE plpgsql AS $$
        BEGIN
          IF OLD.public_id IS NOT NULL AND NEW.public_id IS DISTINCT FROM OLD.public_id THEN
            RAISE EXCEPTION 'operator telephone public identity cannot be changed'
              USING ERRCODE = '23514', CONSTRAINT = 'operator_telephones_public_id_immutable';
          END IF;
          RETURN NEW;
        END;
        $$;
      SQL
      execute(<<~SQL.squish)
        CREATE TRIGGER operator_telephones_public_id_immutability
        BEFORE UPDATE OF public_id ON operator_telephones
        FOR EACH ROW EXECUTE FUNCTION prevent_operator_telephone_public_id_mutation();
      SQL
    end
    # Fixed English schema metadata is not customer-facing localization content.
    # rubocop:disable I18n/RailsI18n/DecorateString
    change_column_comment(
      :operator_telephones, :public_id,
      "Permanent identity; operator_telephones_public_id_immutability rejects issued-ID changes. " \
      "See adr/database-trigger-usage-boundary.md.",
    )
    # rubocop:enable I18n/RailsI18n/DecorateString
  end

  def down
    safety_assured do
      execute("DROP TRIGGER operator_telephones_public_id_immutability ON operator_telephones")
      execute("DROP FUNCTION prevent_operator_telephone_public_id_mutation()")
    end
    change_column_comment(:operator_telephones, :public_id, nil)
  end
end
