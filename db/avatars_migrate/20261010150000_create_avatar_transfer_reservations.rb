# frozen_string_literal: true

class CreateAvatarTransferReservations < ActiveRecord::Migration[8.2]
  REGISTRY = :avatar_transfer_reservations
  DETAIL_TABLES = {
    enterprise_to_enterprise: {
      table: :avatar_enterprise_to_enterprise_transfer_details,
      columns: %i(source_enterprise_public_id destination_enterprise_public_id),
      code: "ee",
    },
    enterprise_to_bureau: {
      table: :avatar_enterprise_to_bureau_transfer_details,
      columns: %i(source_enterprise_public_id destination_bureau_public_id),
      code: "eb",
    },
    bureau_to_enterprise: {
      table: :avatar_bureau_to_enterprise_transfer_details,
      columns: %i(source_bureau_public_id destination_enterprise_public_id),
      code: "be",
    },
    bureau_to_bureau: {
      table: :avatar_bureau_to_bureau_transfer_details,
      columns: %i(source_bureau_public_id destination_bureau_public_id),
      code: "bb",
    },
  }.freeze
  CARDINALITY_FUNCTION = "enforce_avatar_transfer_detail_cardinality"

  def up
    create_registry
    DETAIL_TABLES.each_value do |definition|
      create_detail(definition.fetch(:table), definition.fetch(:columns), definition.fetch(:code))
    end
    add_registry_constraints
    DETAIL_TABLES.each_value { |definition| add_detail_constraints(definition.fetch(:table), definition.fetch(:columns)) }
    safety_assured do
      execute(cardinality_function_sql)
      attach_cardinality_triggers
    end
  end

  def down
    safety_assured do
      detach_cardinality_triggers
      execute("DROP FUNCTION IF EXISTS #{CARDINALITY_FUNCTION}()")
    end
    DETAIL_TABLES.each_value { |definition| drop_table(definition.fetch(:table)) }
    drop_table(REGISTRY)
  end

  private

  def create_registry
    create_table(REGISTRY) do |t|
      t.references(:avatar, null: false, index: false, foreign_key: { on_delete: :restrict })
      t.string(:public_id, null: false, limit: 21)
      t.string(:operation_kind, null: false, limit: 40)
      t.string(:idempotency_key, null: false, limit: 36)
      t.string(:request_fingerprint, null: false, limit: 64)
      t.string(:state, null: false, limit: 20, default: "pending")
      t.datetime(:completed_at)
      t.timestamps
    end
    add_index(REGISTRY, :public_id, unique: true, name: "idx_avatar_transfer_reservations_public_id")
    add_index(REGISTRY, :idempotency_key, unique: true, name: "idx_avatar_transfer_reservations_idempotency")
    add_index(
      REGISTRY, :avatar_id, unique: true, where: "state = 'pending'",
                            name: "idx_avatar_transfer_reservations_one_pending_avatar",
    )
  end

  def create_detail(table, columns, code)
    create_table(table) do |t|
      t.references(
        :transfer_reservation, null: false, index: false,
                               foreign_key: { to_table: REGISTRY, on_delete: :restrict },
      )
      columns.each { |column| t.string(column, null: false, limit: 255) }
      t.string(:request_actor_public_id, null: false, limit: 255)
      t.string(:accept_actor_public_id, limit: 255)
      t.datetime(:requested_at, null: false, default: -> { "CURRENT_TIMESTAMP" })
      t.datetime(:accepted_at)
      t.timestamps
    end
    add_index(
      table, :transfer_reservation_id, unique: true,
                                       name: "idx_av_tr_#{code}_reservation",
    )
  end

  def add_registry_constraints
    add_check_constraint(
      REGISTRY,
      "operation_kind IN ('enterprise_to_enterprise', 'enterprise_to_bureau', " \
      "'bureau_to_enterprise', 'bureau_to_bureau')",
      name: "chk_avatar_transfer_reservations_operation_kind",
    )
    add_check_constraint(
      REGISTRY, "state IN ('pending', 'accepted', 'cancelled', 'expired')",
      name: "chk_avatar_transfer_reservations_state",
    )
    add_check_constraint(
      REGISTRY,
      "idempotency_key ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[47][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'",
      name: "chk_avatar_transfer_reservations_idempotency_uuid",
    )
    add_check_constraint(
      REGISTRY, "char_length(btrim(public_id)) > 0 AND char_length(btrim(request_fingerprint)) > 0",
      name: "chk_avatar_transfer_reservations_nonblank",
    )
  end

  def add_detail_constraints(table, columns)
    identifiers = columns + [:request_actor_public_id]
    expression = identifiers.map { |column| "char_length(btrim(#{column})) > 0" }.join(" AND ")
    add_check_constraint(table, expression, name: "chk_#{table}_nonblank")
  end

  # The deferred trigger is the smallest approved cross-table cardinality guard: four concrete
  # detail tables remain explicit, while the registry cannot commit without exactly one match.
  # rubocop:disable Metrics/MethodLength
  def cardinality_function_sql
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION #{CARDINALITY_FUNCTION}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        reservation_id bigint;
        reservation_kind text;
        detail_count integer;
      BEGIN
        IF TG_TABLE_NAME = '#{REGISTRY}' THEN
          reservation_id := COALESCE(NEW.id, OLD.id);
        ELSE
          reservation_id := COALESCE(NEW.transfer_reservation_id, OLD.transfer_reservation_id);
        END IF;
        SELECT operation_kind INTO reservation_kind FROM #{REGISTRY} WHERE id = reservation_id;
        IF NOT FOUND THEN RETURN NULL; END IF;
        WITH details AS (
          SELECT transfer_reservation_id FROM avatar_enterprise_to_enterprise_transfer_details
          UNION ALL SELECT transfer_reservation_id FROM avatar_enterprise_to_bureau_transfer_details
          UNION ALL SELECT transfer_reservation_id FROM avatar_bureau_to_enterprise_transfer_details
          UNION ALL SELECT transfer_reservation_id FROM avatar_bureau_to_bureau_transfer_details
        )
        SELECT count(*) INTO detail_count FROM details WHERE transfer_reservation_id = reservation_id;
        IF detail_count <> 1 THEN
          RAISE EXCEPTION 'transfer reservation % must have exactly one concrete detail', reservation_id
            USING ERRCODE = '23514';
        END IF;
        IF reservation_kind = 'enterprise_to_enterprise' AND NOT EXISTS (
          SELECT 1 FROM avatar_enterprise_to_enterprise_transfer_details WHERE transfer_reservation_id = reservation_id
        ) THEN
          RAISE EXCEPTION 'transfer reservation % has the wrong concrete detail family', reservation_id
            USING ERRCODE = '23514';
        END IF;
        IF reservation_kind = 'enterprise_to_bureau' AND NOT EXISTS (
          SELECT 1 FROM avatar_enterprise_to_bureau_transfer_details WHERE transfer_reservation_id = reservation_id
        ) THEN
          RAISE EXCEPTION 'transfer reservation % has the wrong concrete detail family', reservation_id
            USING ERRCODE = '23514';
        END IF;
        IF reservation_kind = 'bureau_to_enterprise' AND NOT EXISTS (
          SELECT 1 FROM avatar_bureau_to_enterprise_transfer_details WHERE transfer_reservation_id = reservation_id
        ) THEN
          RAISE EXCEPTION 'transfer reservation % has the wrong concrete detail family', reservation_id
            USING ERRCODE = '23514';
        END IF;
        IF reservation_kind = 'bureau_to_bureau' AND NOT EXISTS (
          SELECT 1 FROM avatar_bureau_to_bureau_transfer_details WHERE transfer_reservation_id = reservation_id
        ) THEN
          RAISE EXCEPTION 'transfer reservation % has the wrong concrete detail family', reservation_id
            USING ERRCODE = '23514';
        END IF;
        RETURN NULL;
      END;
      $$;
    SQL
  end
  # rubocop:enable Metrics/MethodLength

  def attach_cardinality_triggers
    execute(<<~SQL.squish)
      CREATE CONSTRAINT TRIGGER avatar_transfer_reservations_cardinality
      AFTER INSERT OR UPDATE OR DELETE ON #{REGISTRY}
      DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
      EXECUTE FUNCTION #{CARDINALITY_FUNCTION}();
    SQL
    DETAIL_TABLES.each_value do |definition|
      table = definition.fetch(:table)
      code = definition.fetch(:code)
      execute(<<~SQL.squish)
        CREATE CONSTRAINT TRIGGER avatar_transfer_detail_#{code}_cardinality
        AFTER INSERT OR UPDATE OR DELETE ON #{table}
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
        EXECUTE FUNCTION #{CARDINALITY_FUNCTION}();
      SQL
    end
  end

  def detach_cardinality_triggers
    execute("DROP TRIGGER IF EXISTS avatar_transfer_reservations_cardinality ON #{REGISTRY}")
    DETAIL_TABLES.each_value do |definition|
      table = definition.fetch(:table)
      code = definition.fetch(:code)
      execute("DROP TRIGGER IF EXISTS avatar_transfer_detail_#{code}_cardinality ON #{table}")
    end
  end
end
