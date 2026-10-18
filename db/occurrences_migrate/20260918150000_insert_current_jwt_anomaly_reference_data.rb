# frozen_string_literal: true

class InsertCurrentJwtAnomalyReferenceData < ActiveRecord::Migration[8.2]
  STATUS_DATA = {
    0 => "nothing",
    1 => "legacy_nothing",
    2 => "active",
    3 => "inactive",
    4 => "deleted",
  }.freeze

  ACTIVE_STATUS_ID = 2
  PUBLIC_ID_PREFIX = "jwt_occurrence_"
  PUBLIC_ID_MAX_NUMBER = 999_999

  COMMON_REASONS = {
    "MALFORMED_TOKEN" => "token is malformed",
    "UNKNOWN_KID" => "kid is unknown",
    "MISSING_KID" => "kid claim is missing",
    "ALG_NONE" => "alg none was supplied",
    "ALG_MISMATCH" => "algorithm does not match expected value",
    "MISSING_TYP" => "typ claim is missing",
    "TYP_MISMATCH" => "typ does not match expected value",
    "MISSING_ISS" => "issuer claim is missing",
    "ISS_MISMATCH" => "issuer does not match expected value",
    "MISSING_AUD" => "audience claim is missing",
    "AUD_MISMATCH" => "audience does not match expected value",
    "MISSING_EXP" => "expiration claim is missing",
    "EXPIRED" => "token is expired",
    "MISSING_NBF" => "not before claim is missing",
    "IMMATURE" => "token is not valid yet",
    "IAT_INVALID" => "issued at claim is invalid",
    "MISSING_JTI" => "jti claim is missing",
    "SIGNATURE_INVALID" => "signature verification failed",
    "DECODE_ERROR" => "decode failed before classification",
    "OTHER" => "uncategorized jwt anomaly",
  }.freeze

  AUTH_REASONS = {
    "MISSING_SUB" => "subject claim is missing",
    "MISSING_SID" => "session id claim is missing",
    "MISSING_ACT" => "actor claim is missing",
    "ACT_MISMATCH" => "actor does not match expected value",
    "CLAIM_INVALID" => "claims failed structural or semantic validation",
    "DECODE_FAILED" => "token decoding or verification failed",
  }.freeze

  CONTEXTS = {
    "AUTH_CLIENT" => "Client auth JWT",
    "AUTH_OPERATOR" => "Operator auth JWT",
    "AUTH_VISITOR" => "Visitor auth JWT",
  }.freeze

  def up
    seed_into(connection)
  end

  # Structure loads mark migrations as applied without replaying their data
  # inserts. db/seeds.rb calls this same idempotent writer on the occurrence
  # connection so the current runtime catalog is reproducible without making
  # a migration depend on the primary connection.
  def seed_into(target_connection)
    unless target_connection.data_source_exists?("jwt_occurrence_statuses") &&
        target_connection.data_source_exists?("jwt_occurrences")
      raise ActiveRecord::MigrationError,
            "JWT anomaly reference tables must exist before current catalog data is inserted"
    end

    next_public_number = next_public_number(target_connection)

    safety_assured do
      STATUS_DATA.each do |id, name|
        target_connection.execute(<<~SQL.squish)
          INSERT INTO jwt_occurrence_statuses (id, name)
          VALUES (#{id}, #{target_connection.quote(name)})
          ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name
        SQL
      end

      catalog_rows.each do |body, memo|
        existing_status = existing_status_id(target_connection, body)
        if existing_status
          unless existing_status == ACTIVE_STATUS_ID
            raise ActiveRecord::MigrationError,
                  "JWT anomaly reference #{body} exists with status #{existing_status}, expected active"
          end

          next
        end

        next_public_number += 1
        raise ActiveRecord::MigrationError, "JWT anomaly public_id range exhausted" if
          next_public_number > PUBLIC_ID_MAX_NUMBER

        public_id = format("#{PUBLIC_ID_PREFIX}%06d", next_public_number)
        target_connection.execute(<<~SQL.squish)
          INSERT INTO jwt_occurrences (body, memo, public_id, status_id, created_at, updated_at)
          VALUES (
            #{target_connection.quote(body)},
            #{target_connection.quote(memo)},
            #{target_connection.quote(public_id)},
            #{ACTIVE_STATUS_ID},
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
          )
        SQL
      end
    end

    ensure_sequence!(target_connection, :jwt_occurrence_statuses, STATUS_DATA.keys.max)
    max_id = Integer(
      target_connection.select_value("SELECT COALESCE(MAX(id), 0) FROM jwt_occurrences").to_s,
      10,
    )
    ensure_sequence!(target_connection, :jwt_occurrences, max_id)
  end

  # Reference rows may already be linked from persisted anomaly events. They
  # are retained on rollback so a migration reversal cannot destroy history.
  def down
  end

  private

  def catalog_rows
    CONTEXTS.flat_map do |context_code, context_name|
      COMMON_REASONS.merge(AUTH_REASONS).map do |reason_code, reason_description|
        body = "#{context_code}_#{reason_code}"
        memo = "#{context_name} anomaly: #{reason_description}."
        [body, memo]
      end
    end
  end

  def existing_status_id(target_connection, body)
    value = target_connection.select_value(<<~SQL.squish)
      SELECT status_id
      FROM jwt_occurrences
      WHERE body = #{target_connection.quote(body)}
      LIMIT 1
    SQL
    value&.to_i
  end

  def next_public_number(target_connection)
    value = target_connection.select_value(<<~SQL.squish)
      SELECT COALESCE(MAX(CAST(substring(public_id FROM 'jwt_occurrence_([0-9]+)$') AS bigint)), 0)
      FROM jwt_occurrences
      WHERE public_id ~ '^jwt_occurrence_[0-9]+$'
    SQL
    Integer(value.to_s, 10)
  end

  def ensure_sequence!(target_connection, table_name, max_id)
    sequence_name = target_connection.select_value(
      "SELECT pg_get_serial_sequence(#{target_connection.quote(table_name.to_s)}, 'id')",
    )
    return if sequence_name.blank? || max_id <= 0

    target_connection.execute(
      "SELECT setval(#{target_connection.quote(sequence_name)}, #{Integer(max_id)}, true)",
    )
  end
end
