# frozen_string_literal: true

class PreserveVisitorCredentialRegistrationOtpProof < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLES = %i(visitor_emails visitor_telephones).freeze

  SHAPE_CONSTRAINT = <<~SQL.squish.freeze
    credential_registration_otp_context IS NULL OR (
      jsonb_typeof(credential_registration_otp_context) = 'object'
      AND credential_registration_otp_context ?& ARRAY['version', 'surface', 'purpose', 'flow_ref', 'browser_digest', 'session_ref', 'owner_ref', 'contact_ref', 'destination_digest', 'counter', 'code_digest', 'issued_at', 'expires_at', 'verified_at', 'result_expires_at']
      AND credential_registration_otp_context - ARRAY['version', 'surface', 'purpose', 'flow_ref', 'browser_digest', 'session_ref', 'owner_ref', 'contact_ref', 'destination_digest', 'counter', 'code_digest', 'issued_at', 'expires_at', 'verified_at', 'result_expires_at'] = '{}'::jsonb
      AND credential_registration_otp_context->'version' = '1'::jsonb
      AND jsonb_typeof(credential_registration_otp_context->'surface') = 'string'
      AND jsonb_typeof(credential_registration_otp_context->'purpose') = 'string'
      AND jsonb_typeof(credential_registration_otp_context->'flow_ref') = 'string'
      AND jsonb_typeof(credential_registration_otp_context->'browser_digest') = 'string'
      AND jsonb_typeof(credential_registration_otp_context->'session_ref') = 'string'
      AND jsonb_typeof(credential_registration_otp_context->'owner_ref') = 'string'
      AND jsonb_typeof(credential_registration_otp_context->'contact_ref') = 'string'
      AND jsonb_typeof(credential_registration_otp_context->'destination_digest') = 'string'
      AND jsonb_typeof(credential_registration_otp_context->'counter') = 'string'
      AND jsonb_typeof(credential_registration_otp_context->'code_digest') = 'string'
      AND jsonb_typeof(credential_registration_otp_context->'issued_at') = 'string'
      AND jsonb_typeof(credential_registration_otp_context->'expires_at') = 'string'
      AND credential_registration_otp_context->>'surface' = 'com'
      AND credential_registration_otp_context->>'purpose' = 'credential_registration'
      AND credential_registration_otp_context->>'flow_ref' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      AND credential_registration_otp_context->>'session_ref' ~ '^[A-Za-z0-9_-]{1,21}$'
      AND credential_registration_otp_context->>'owner_ref' ~ '^[A-Za-z0-9_-]{1,21}$'
      AND credential_registration_otp_context->>'contact_ref' = public_id
      AND credential_registration_otp_context->>'browser_digest' ~ '^[0-9a-f]{64}$'
      AND credential_registration_otp_context->>'destination_digest' ~ '^[0-9a-f]{64}$'
      AND credential_registration_otp_context->>'code_digest' ~ '^[0-9a-f]{64}$'
      AND credential_registration_otp_context->>'counter' ~ '^(0|[1-9][0-9]{0,19})$'
      AND (credential_registration_otp_context->>'counter')::numeric <= 18446744073709551615
      AND (credential_registration_otp_context->'issued_at' = 'null'::jsonb OR (
        credential_registration_otp_context->>'issued_at' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{6}Z$'
        AND isfinite((credential_registration_otp_context->>'issued_at')::timestamptz)
      ))
      AND (credential_registration_otp_context->'expires_at' = 'null'::jsonb OR (
        credential_registration_otp_context->>'expires_at' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{6}Z$'
        AND isfinite((credential_registration_otp_context->>'expires_at')::timestamptz)
      ))
      AND (credential_registration_otp_context->'verified_at' = 'null'::jsonb OR (
        credential_registration_otp_context->>'verified_at' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{6}Z$'
        AND isfinite((credential_registration_otp_context->>'verified_at')::timestamptz)
      ))
      AND (credential_registration_otp_context->'result_expires_at' = 'null'::jsonb OR (
        credential_registration_otp_context->>'result_expires_at' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{6}Z$'
        AND isfinite((credential_registration_otp_context->>'result_expires_at')::timestamptz)
      ))
      AND (credential_registration_otp_context->>'issued_at')::timestamptz < (credential_registration_otp_context->>'expires_at')::timestamptz
      AND (
        (credential_registration_otp_context->'verified_at' = 'null'::jsonb AND credential_registration_otp_context->'result_expires_at' = 'null'::jsonb)
        OR (
          jsonb_typeof(credential_registration_otp_context->'verified_at') = 'string'
          AND jsonb_typeof(credential_registration_otp_context->'result_expires_at') = 'string'
          AND (credential_registration_otp_context->>'issued_at')::timestamptz <= (credential_registration_otp_context->>'verified_at')::timestamptz
          AND (credential_registration_otp_context->>'verified_at')::timestamptz < (credential_registration_otp_context->>'expires_at')::timestamptz
          AND (credential_registration_otp_context->>'verified_at')::timestamptz < (credential_registration_otp_context->>'result_expires_at')::timestamptz
          AND (credential_registration_otp_context->>'result_expires_at')::timestamptz <= (credential_registration_otp_context->>'verified_at')::timestamptz + interval '60 seconds'
        )
      )
    ) IS TRUE
  SQL

  def up
    TABLES.each do |table|
      add_check_constraint(
        table,
        SHAPE_CONSTRAINT,
        name: "#{table}_credential_registration_otp_shape", validate: false,
      )
      validate_check_constraint(table, name: "#{table}_credential_registration_otp_shape")
    end

    # Owner-approved bounded DDL; existing Contact and proof facts are preserved.
    safety_assured do
      execute(<<~SQL.squish)
        CREATE FUNCTION enforce_visitor_credential_registration_otp_proof() RETURNS trigger
        LANGUAGE plpgsql AS $$
        BEGIN
          IF OLD.credential_registration_otp_context->>'verified_at' IS NOT NULL AND
             NEW.credential_registration_otp_context IS DISTINCT FROM OLD.credential_registration_otp_context THEN
            RAISE EXCEPTION 'committed credential registration OTP proof is immutable';
          END IF;
          RETURN NEW;
        END;
        $$;
      SQL
      TABLES.each do |table|
        execute(<<~SQL.squish)
          CREATE TRIGGER #{table}_credential_registration_otp_proof_trigger
          BEFORE UPDATE OF credential_registration_otp_context ON #{table}
          FOR EACH ROW EXECUTE FUNCTION enforce_visitor_credential_registration_otp_proof();
        SQL
      end
    end
  end

  def down
    safety_assured do
      TABLES.each do |table|
        execute("DROP TRIGGER #{table}_credential_registration_otp_proof_trigger ON #{table}")
      end
      execute("DROP FUNCTION enforce_visitor_credential_registration_otp_proof()")
    end
    TABLES.each do |table|
      remove_check_constraint(table, name: "#{table}_credential_registration_otp_shape")
    end
  end
end
