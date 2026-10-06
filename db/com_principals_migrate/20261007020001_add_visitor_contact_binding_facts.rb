# frozen_string_literal: true

class AddVisitorContactBindingFacts < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  CONTACTS = {
    visitor_emails: { owner: "visitor_id", digest: "address_digest", status: "visitor_email_status_id",
                      effective_statuses: [2, 3], signup_status: 7 },
    visitor_telephones: { owner: "visitor_id", digest: "number_digest", status: "visitor_telephone_status_id",
                          effective_statuses: [2, 3], signup_status: 7 },
  }.freeze

  def up
    safety_assured do
      CONTACTS.each do |table, facts|
        add_column(table, :binding_finalized_at, :datetime)
        add_column(table, :binding_released_at, :datetime)
        classify_existing_rows!(table, facts)
        reject_effective_conflicts!(table, facts)
        replace_legacy_indexes!(table, facts)
        add_fact_constraints!(table, facts)
        add_fact_trigger!(table, facts)
      end
    end
  end

  def down
    safety_assured do
      CONTACTS.each do |table, facts|
        remove_fact_trigger!(table)
        remove_check_constraint(table, name: "#{table}_binding_release_requires_finalization", if_exists: true)
        remove_check_constraint(table, name: "#{table}_binding_effective_digest_present", if_exists: true)
        remove_index(table, name: "#{table}_effective_owner", algorithm: :concurrently, if_exists: true)
        remove_index(table, name: "#{table}_effective_digest", algorithm: :concurrently, if_exists: true)
        restore_legacy_indexes!(table, facts)
        remove_column(table, :binding_released_at)
        remove_column(table, :binding_finalized_at)
      end
    end
  end

  private

  def classify_existing_rows!(table, facts)
    statuses = facts.fetch(:effective_statuses).join(",")
    execute <<~SQL
      UPDATE #{table}
         SET binding_finalized_at = CURRENT_TIMESTAMP
       WHERE #{facts.fetch(:status)} IN (#{statuses})
          OR #{facts.fetch(:status)} = #{facts.fetch(:signup_status)}
    SQL
  end

  def reject_effective_conflicts!(table, facts)
    digest_conflicts = connection.select_values(<<~SQL)
      SELECT string_agg(id::text, ',' ORDER BY id)
        FROM #{table}
       WHERE binding_finalized_at IS NOT NULL AND binding_released_at IS NULL
       GROUP BY #{facts.fetch(:digest)}
      HAVING #{facts.fetch(:digest)} IS NULL OR COUNT(*) > 1
    SQL
    owner_conflicts = connection.select_values(<<~SQL)
      SELECT string_agg(id::text, ',' ORDER BY id)
        FROM #{table}
       WHERE binding_finalized_at IS NOT NULL AND binding_released_at IS NULL
       GROUP BY #{facts.fetch(:owner)}
      HAVING COUNT(*) > 1
    SQL
    return if digest_conflicts.empty? && owner_conflicts.empty?

    raise ActiveRecord::MigrationError,
          "#{table} has unresolved effective contact binding conflicts: " \
          "digest rows=#{digest_conflicts.join(';')} owner rows=#{owner_conflicts.join(';')}"
  end

  def replace_legacy_indexes!(table, facts)
    remove_index(table, name: "index_#{table}_on_active_#{facts.fetch(:digest).delete_suffix('_digest')}_digest",
                 algorithm: :concurrently, if_exists: true)
    add_index(table, facts.fetch(:digest), unique: true,
              where: "binding_finalized_at IS NOT NULL AND binding_released_at IS NULL",
              name: "#{table}_effective_digest", algorithm: :concurrently)
    add_index(table, facts.fetch(:owner), unique: true,
              where: "binding_finalized_at IS NOT NULL AND binding_released_at IS NULL",
              name: "#{table}_effective_owner", algorithm: :concurrently)
  end

  def restore_legacy_indexes!(table, facts)
    add_index(table, facts.fetch(:digest), unique: true,
              where: "#{facts.fetch(:digest)} IS NOT NULL AND #{facts.fetch(:status)} <> 4",
              name: "index_#{table}_on_active_#{facts.fetch(:digest).delete_suffix('_digest')}_digest",
              algorithm: :concurrently, if_not_exists: true)
  end

  def add_fact_constraints!(table, facts)
    add_check_constraint(table, "binding_released_at IS NULL OR binding_finalized_at IS NOT NULL",
                        name: "#{table}_binding_release_requires_finalization")
    add_check_constraint(
      table,
      "binding_finalized_at IS NULL OR (#{facts.fetch(:digest)} IS NOT NULL AND #{facts.fetch(:digest)} <> '')",
      name: "#{table}_binding_effective_digest_present",
    )
  end

  def add_fact_trigger!(table, facts)
    function = "enforce_#{table}_binding_facts"
    execute <<~SQL
      CREATE OR REPLACE FUNCTION #{function}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF OLD.binding_finalized_at IS NOT NULL AND
           (NEW.#{facts.fetch(:owner)} IS DISTINCT FROM OLD.#{facts.fetch(:owner)} OR
            NEW.#{facts.fetch(:digest)} IS DISTINCT FROM OLD.#{facts.fetch(:digest)}) THEN
          RAISE EXCEPTION 'effective contact binding owner and digest are immutable';
        END IF;
        IF OLD.binding_finalized_at IS NOT NULL AND
           NEW.binding_finalized_at IS DISTINCT FROM OLD.binding_finalized_at THEN
          RAISE EXCEPTION 'effective contact binding finalization is immutable';
        END IF;
        IF OLD.binding_released_at IS NOT NULL AND
           NEW.binding_released_at IS DISTINCT FROM OLD.binding_released_at THEN
          RAISE EXCEPTION 'released contact binding cannot be reactivated or rewritten';
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
    execute <<~SQL
      CREATE TRIGGER #{table}_binding_facts_trigger
      BEFORE UPDATE ON #{table}
      FOR EACH ROW EXECUTE FUNCTION #{function}();
    SQL
  end

  def remove_fact_trigger!(table)
    execute "DROP TRIGGER IF EXISTS #{table}_binding_facts_trigger ON #{table}"
    execute "DROP FUNCTION IF EXISTS enforce_#{table}_binding_facts()"
  end
end
