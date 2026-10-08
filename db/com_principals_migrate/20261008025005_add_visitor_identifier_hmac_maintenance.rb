# frozen_string_literal: true

# SQL identifiers and DDL statements must not pass through localization.
# rubocop:disable I18n/RailsI18n/DecorateString

require "digest"

class AddVisitorIdentifierHmacMaintenance < ActiveRecord::Migration[8.2]
  CONTACTS = {
    email: { table: "visitor_emails", digest: "address_digest" },
    telephone: { table: "visitor_telephones", digest: "number_digest" },
  }.freeze
  AUDIT_TABLE = :visitor_identifier_rotation_audits

  public

  def up
    safety_assured do
      create_table(AUDIT_TABLE) do |t|
        t.uuid(:operation_ref, null: false)
        t.string(:channel, null: false)
        t.bigint(:record_id, null: false)
        t.string(:actor_role, null: false)
        t.datetime(:occurred_at, null: false)
      end
      add_check_constraint(AUDIT_TABLE, "channel IN ('email', 'telephone')", name: "visitor_rotation_channel")
      add_check_constraint(AUDIT_TABLE, "record_id > 0 AND actor_role <> ''", name: "visitor_rotation_subject")
      add_index(AUDIT_TABLE, %i(operation_ref channel record_id), unique: true, name: "visitor_rotation_operation")
      CONTACTS.each do |channel, facts|
        install_domain!(channel, facts)
        install_binding_guard!(channel, facts, maintenance: true)
      end
      install_audit_guard!
    end
  end

  def down
    safety_assured do
      unless connection.select_value("SELECT COUNT(*) FROM public.#{AUDIT_TABLE}").to_i.zero?
        raise ActiveRecord::MigrationError, "Rotation audit retention must be resolved before schema rollback"
      end

      CONTACTS.each do |channel, facts|
        install_binding_guard!(channel, facts, maintenance: false)
        execute("DROP FUNCTION public.rotate_#{facts.fetch(:table)}_hmac(bigint, text, text, uuid)")
        execute("REVOKE ALL ON public.#{facts.fetch(:table)} FROM #{quote_role(channel, :definer)}")
      end
      execute("DROP TRIGGER visitor_rotation_audit_guard ON public.#{AUDIT_TABLE}")
      execute("DROP FUNCTION public.enforce_visitor_rotation_audit()")
      drop_table(AUDIT_TABLE)
      CONTACTS.each_key do |channel|
        [:definer, :caller].each do |kind|
          execute("REVOKE ALL ON SCHEMA public FROM #{quote_role(channel, kind)}")
          execute("DROP ROLE #{quote_role(channel, kind)}")
        end
      end
    end
  end

  private

  def role_name(channel, kind)
    database = connection.select_value("SELECT current_database()")
    "umaxica_com_#{channel}_hmac_#{kind}_#{Digest::SHA256.hexdigest(database).first(12)}"
  end

  def quote_role(channel, kind)
    connection.quote_column_name(role_name(channel, kind))
  end

  def install_domain!(channel, facts)
    definer = quote_role(channel, :definer)
    caller = quote_role(channel, :caller)
    table = facts.fetch(:table)
    digest = facts.fetch(:digest)
    function = "public.rotate_#{table}_hmac(bigint, text, text, uuid)"
    execute("CREATE ROLE #{definer} NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT")
    execute("CREATE ROLE #{caller} NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT")
    execute("GRANT USAGE ON SCHEMA public TO #{definer}, #{caller}")
    execute("GRANT SELECT(id, #{digest}), UPDATE(#{digest}) ON public.#{table} TO #{definer}")
    execute("GRANT INSERT ON public.#{AUDIT_TABLE} TO #{definer}")
    execute("GRANT USAGE ON SEQUENCE public.#{AUDIT_TABLE}_id_seq TO #{definer}")
    execute(<<~SQL.squish)
      CREATE FUNCTION public.rotate_#{table}_hmac(
        p_record_id bigint, p_new_digest text, p_expected_digest text, p_operation_ref uuid
      ) RETURNS boolean
      LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
      DECLARE prior_digest text;
      BEGIN
        IF current_user <> #{connection.quote(role_name(channel, :definer))} THEN
          RAISE EXCEPTION 'identifier rotation function owner is invalid';
        END IF;
        IF p_record_id IS NULL OR p_record_id <= 0 OR p_operation_ref IS NULL OR
           p_new_digest IS NULL OR p_new_digest !~ '^[0-9a-f]{64}$' THEN
          RAISE EXCEPTION 'invalid identifier rotation arguments';
        END IF;
        SELECT #{digest} INTO prior_digest FROM public.#{table} WHERE id = p_record_id FOR UPDATE;
        IF NOT FOUND THEN
          RAISE EXCEPTION 'identifier rotation source is unavailable';
        END IF;
        IF prior_digest IS DISTINCT FROM p_expected_digest THEN
          RAISE EXCEPTION 'identifier rotation source changed' USING ERRCODE = '40001';
        END IF;
        IF prior_digest IS NOT DISTINCT FROM p_new_digest THEN
          RETURN FALSE;
        END IF;
        UPDATE public.#{table} SET #{digest} = p_new_digest WHERE id = p_record_id;
        INSERT INTO public.#{AUDIT_TABLE}(operation_ref, channel, record_id, actor_role, occurred_at)
          VALUES (p_operation_ref, '#{channel}', p_record_id, session_user, clock_timestamp());
        RETURN TRUE;
      END;
      $$;
    SQL
    restrict_function_authority!(function, definer, caller)
  end

  def restrict_function_authority!(function, definer, caller)
    execute("GRANT CREATE ON SCHEMA public TO #{definer}")
    execute("ALTER FUNCTION #{function} OWNER TO #{definer}")
    execute("REVOKE CREATE ON SCHEMA public FROM #{definer}")
    execute("REVOKE ALL ON FUNCTION #{function} FROM PUBLIC")
    execute("GRANT EXECUTE ON FUNCTION #{function} TO #{caller}")
  end

  def install_audit_guard!
    email_role = connection.quote(role_name(:email, :definer))
    telephone_role = connection.quote(role_name(:telephone, :definer))
    execute(<<~SQL.squish)
      CREATE FUNCTION public.enforce_visitor_rotation_audit() RETURNS trigger
      LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
      BEGIN
        IF TG_OP = 'UPDATE' THEN
          RAISE EXCEPTION 'identifier rotation audit is append-only';
        END IF;
        IF NOT ((current_user = #{email_role} AND NEW.channel = 'email') OR
                (current_user = #{telephone_role} AND NEW.channel = 'telephone')) THEN
          RAISE EXCEPTION 'identifier rotation audit requires its domain function';
        END IF;
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER visitor_rotation_audit_guard
        BEFORE INSERT OR UPDATE ON public.#{AUDIT_TABLE}
        FOR EACH ROW EXECUTE FUNCTION public.enforce_visitor_rotation_audit();
    SQL
  end

  def install_binding_guard!(channel, facts, maintenance:)
    table = facts.fetch(:table)
    digest = facts.fetch(:digest)
    role = connection.quote(role_name(channel, :definer))
    digest_exception = maintenance ? "AND current_user <> #{role}" : ""
    exclusive_update =
      if maintenance
        <<~SQL.squish
          IF current_user = #{role} AND
             (to_jsonb(NEW) - '#{digest}') IS DISTINCT FROM (to_jsonb(OLD) - '#{digest}') THEN
            RAISE EXCEPTION 'identifier rotation may change only its digest';
          END IF;
        SQL
      else
        ""
      end
    execute(<<~SQL.squish)
      CREATE OR REPLACE FUNCTION public.enforce_#{table}_binding_facts() RETURNS trigger
      LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $$
      BEGIN
        #{exclusive_update}
        IF OLD.binding_finalized_at IS NOT NULL AND
           (NEW.visitor_id IS DISTINCT FROM OLD.visitor_id OR
            (NEW.#{digest} IS DISTINCT FROM OLD.#{digest} #{digest_exception})) THEN
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
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
