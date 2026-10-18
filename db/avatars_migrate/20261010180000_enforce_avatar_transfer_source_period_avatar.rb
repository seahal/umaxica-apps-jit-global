# frozen_string_literal: true

class EnforceAvatarTransferSourcePeriodAvatar < ActiveRecord::Migration[8.2]
  REGISTRY = :avatar_transfer_reservations
  DETAILS = {
    ee: :avatar_enterprise_to_enterprise_transfer_details,
    eb: :avatar_enterprise_to_bureau_transfer_details,
    be: :avatar_bureau_to_enterprise_transfer_details,
    bb: :avatar_bureau_to_bureau_transfer_details,
  }.freeze
  FUNCTION = "enforce_avatar_transfer_source_period_avatar"

  def up
    safety_assured do
      execute(function_sql)
      attach_trigger(REGISTRY, "avatar_transfer_reservations_source_period_avatar_integrity")
      DETAILS.each do |code, table|
        attach_trigger(table, "avatar_transfer_detail_#{code}_source_period_avatar_integrity")
      end
    end
  end

  def down
    safety_assured do
      detach_trigger(REGISTRY, "avatar_transfer_reservations_source_period_avatar_integrity")
      DETAILS.each do |code, table|
        detach_trigger(table, "avatar_transfer_detail_#{code}_source_period_avatar_integrity")
      end
      execute("DROP FUNCTION IF EXISTS #{FUNCTION}()")
    end
  end

  private

  # This is a deferred cross-table integrity guard. It does not choose an owner, rewrite a
  # transfer, or emit side effects: it only rejects a detail whose source period belongs to a
  # different Avatar than the reservation. SQLSTATE 23514 is shared with the registry's other
  # deferred cardinality guards so callers can classify the rejected integrity boundary.
  # rubocop:disable Metrics/MethodLength
  def function_sql
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION #{FUNCTION}() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        reservation_id bigint;
        reservation_avatar_id bigint;
      BEGIN
        IF TG_TABLE_NAME = '#{REGISTRY}' THEN
          reservation_id := COALESCE(NEW.id, OLD.id);
        ELSE
          reservation_id := COALESCE(NEW.transfer_reservation_id, OLD.transfer_reservation_id);
        END IF;

        SELECT avatar_id INTO reservation_avatar_id
          FROM #{REGISTRY}
         WHERE id = reservation_id;
        IF NOT FOUND THEN
          RETURN NULL;
        END IF;

        IF EXISTS (
          SELECT 1
            FROM avatar_enterprise_to_enterprise_transfer_details detail
            JOIN avatar_enterprise_ownership_periods period
              ON period.id = detail.source_ownership_period_id
           WHERE detail.transfer_reservation_id = reservation_id
             AND period.avatar_id IS DISTINCT FROM reservation_avatar_id
        ) OR EXISTS (
          SELECT 1
            FROM avatar_enterprise_to_bureau_transfer_details detail
            JOIN avatar_enterprise_ownership_periods period
              ON period.id = detail.source_ownership_period_id
           WHERE detail.transfer_reservation_id = reservation_id
             AND period.avatar_id IS DISTINCT FROM reservation_avatar_id
        ) OR EXISTS (
          SELECT 1
            FROM avatar_bureau_to_enterprise_transfer_details detail
            JOIN avatar_bureau_ownership_periods period
              ON period.id = detail.source_ownership_period_id
           WHERE detail.transfer_reservation_id = reservation_id
             AND period.avatar_id IS DISTINCT FROM reservation_avatar_id
        ) OR EXISTS (
          SELECT 1
            FROM avatar_bureau_to_bureau_transfer_details detail
            JOIN avatar_bureau_ownership_periods period
              ON period.id = detail.source_ownership_period_id
           WHERE detail.transfer_reservation_id = reservation_id
             AND period.avatar_id IS DISTINCT FROM reservation_avatar_id
        ) THEN
          RAISE EXCEPTION 'transfer reservation % source ownership period belongs to another avatar',
            reservation_id USING ERRCODE = '23514';
        END IF;

        RETURN NULL;
      END;
      $$;
    SQL
  end
  # rubocop:enable Metrics/MethodLength

  def attach_trigger(table, name)
    execute(<<~SQL.squish)
      CREATE CONSTRAINT TRIGGER #{name}
      AFTER INSERT OR UPDATE OR DELETE ON #{table}
      DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
      EXECUTE FUNCTION #{FUNCTION}();
    SQL
  end

  def detach_trigger(table, name)
    execute("DROP TRIGGER IF EXISTS #{name} ON #{table}")
  end
end
