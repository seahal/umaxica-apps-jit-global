# frozen_string_literal: true

class InsertCurrentJwtAnomalyReferenceData < ActiveRecord::Migration[8.2]
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
    unless table_exists?(:jwt_occurrence_statuses) && table_exists?(:jwt_occurrences)
      raise ActiveRecord::MigrationError,
            "JWT anomaly reference tables must exist before current catalog data is inserted"
    end

    next_public_number = next_public_number()

    safety_assured do
      catalog_rows.each do |body, memo|
        existing_status = existing_status_id(body)
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
        execute(<<~SQL.squish)
          INSERT INTO jwt_occurrences (body, memo, public_id, status_id, created_at, updated_at)
          VALUES (
            #{connection.quote(body)},
            #{connection.quote(memo)},
            #{connection.quote(public_id)},
            #{ACTIVE_STATUS_ID},
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
          )
        SQL
      end
    end
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

  def existing_status_id(body)
    value = select_value(<<~SQL.squish)
      SELECT status_id
      FROM jwt_occurrences
      WHERE body = #{connection.quote(body)}
      LIMIT 1
    SQL
    value&.to_i
  end

  def next_public_number
    value = select_value(<<~SQL.squish)
      SELECT COALESCE(MAX(CAST(substring(public_id FROM 'jwt_occurrence_([0-9]+)$') AS bigint)), 0)
      FROM jwt_occurrences
      WHERE public_id ~ '^jwt_occurrence_[0-9]+$'
    SQL
    Integer(value.to_s, 10)
  end
end
