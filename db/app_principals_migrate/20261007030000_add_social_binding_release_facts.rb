# frozen_string_literal: true

class AddSocialBindingReleaseFacts < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLE = :client_external_identities
  CLIENT_PROVIDER_INDEX = "idx_client_external_identities_client_provider"
  ISSUER_SUBJECT_INDEX = "idx_client_external_identities_issuer_subject"

  def up
    safety_assured do
      add_column(TABLE, :released_at, :datetime)
      reject_existing_conflicts!
      remove_index(TABLE, name: CLIENT_PROVIDER_INDEX, algorithm: :concurrently)
      remove_index(TABLE, name: ISSUER_SUBJECT_INDEX, algorithm: :concurrently)
      add_index(TABLE, :client_id, unique: true, where: "released_at IS NULL",
                name: CLIENT_PROVIDER_INDEX, algorithm: :concurrently)
      add_index(TABLE, %i(issuer subject), unique: true, where: "released_at IS NULL",
                name: ISSUER_SUBJECT_INDEX, algorithm: :concurrently)
      add_release_trigger!
    end
  end

  def down
    safety_assured do
      remove_release_trigger!
      remove_index(TABLE, name: CLIENT_PROVIDER_INDEX, algorithm: :concurrently, if_exists: true)
      remove_index(TABLE, name: ISSUER_SUBJECT_INDEX, algorithm: :concurrently, if_exists: true)
      add_index(TABLE, %i(issuer subject), unique: true, name: ISSUER_SUBJECT_INDEX,
                algorithm: :concurrently, if_not_exists: true)
      add_index(TABLE, %i(client_id provider), unique: true, name: CLIENT_PROVIDER_INDEX,
                algorithm: :concurrently, if_not_exists: true)
      remove_column(TABLE, :released_at)
    end
  end

  private

  def reject_existing_conflicts!
    conflicts = connection.select_values(<<~SQL)
      SELECT string_agg(id::text, ',' ORDER BY id)
        FROM client_external_identities
       WHERE released_at IS NULL
       GROUP BY issuer, subject
      HAVING COUNT(*) > 1
      UNION ALL
      SELECT string_agg(id::text, ',' ORDER BY id)
        FROM client_external_identities
       WHERE released_at IS NULL
       GROUP BY client_id
      HAVING COUNT(*) > 1
    SQL
    return if conflicts.empty?

    raise ActiveRecord::MigrationError,
          "client_external_identities has unresolved active binding conflicts: rows=#{conflicts.join(';')}"
  end

  def add_release_trigger!
    execute <<~SQL
      CREATE OR REPLACE FUNCTION enforce_client_external_identity_binding_facts() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.client_id IS DISTINCT FROM OLD.client_id OR
           NEW.provider IS DISTINCT FROM OLD.provider OR
           NEW.issuer IS DISTINCT FROM OLD.issuer OR
           NEW.subject IS DISTINCT FROM OLD.subject THEN
          RAISE EXCEPTION 'external identity binding owner and subject are immutable';
        END IF;
        IF OLD.released_at IS NOT NULL AND
           NEW.released_at IS DISTINCT FROM OLD.released_at THEN
          RAISE EXCEPTION 'released external identity cannot be reactivated or rewritten';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
    execute <<~SQL
      CREATE TRIGGER client_external_identities_binding_facts_trigger
      BEFORE UPDATE ON client_external_identities
      FOR EACH ROW EXECUTE FUNCTION enforce_client_external_identity_binding_facts();
    SQL
  end

  def remove_release_trigger!
    execute "DROP TRIGGER IF EXISTS client_external_identities_binding_facts_trigger ON client_external_identities"
    execute "DROP FUNCTION IF EXISTS enforce_client_external_identity_binding_facts()"
  end
end
