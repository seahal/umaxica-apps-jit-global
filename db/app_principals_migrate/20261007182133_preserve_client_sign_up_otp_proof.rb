# frozen_string_literal: true

class PreserveClientSignUpOtpProof < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLES = %i(client_emails client_telephones).freeze

  CONTEXT_SHAPE = <<~SQL.squish.freeze
    sign_up_otp_context IS NULL OR (
      jsonb_typeof(sign_up_otp_context) = 'object'
      AND sign_up_otp_context ?& ARRAY['version', 'surface', 'purpose', 'flow_ref', 'nonce_digest', 'owner_ref', 'contact_ref', 'destination_digest', 'counter', 'code_digest', 'issued_at', 'expires_at', 'verified_at', 'result_expires_at']
      AND sign_up_otp_context - ARRAY['version', 'surface', 'purpose', 'flow_ref', 'nonce_digest', 'owner_ref', 'contact_ref', 'destination_digest', 'counter', 'code_digest', 'issued_at', 'expires_at', 'verified_at', 'result_expires_at'] = '{}'::jsonb
      AND sign_up_otp_context->'version' = '1'::jsonb
      AND jsonb_typeof(sign_up_otp_context->'surface') = 'string'
      AND jsonb_typeof(sign_up_otp_context->'purpose') = 'string'
      AND jsonb_typeof(sign_up_otp_context->'flow_ref') = 'string'
      AND jsonb_typeof(sign_up_otp_context->'nonce_digest') = 'string'
      AND jsonb_typeof(sign_up_otp_context->'owner_ref') = 'string'
      AND jsonb_typeof(sign_up_otp_context->'contact_ref') = 'string'
      AND jsonb_typeof(sign_up_otp_context->'destination_digest') = 'string'
      AND jsonb_typeof(sign_up_otp_context->'counter') = 'string'
      AND jsonb_typeof(sign_up_otp_context->'code_digest') = 'string'
      AND jsonb_typeof(sign_up_otp_context->'issued_at') = 'string'
      AND jsonb_typeof(sign_up_otp_context->'expires_at') = 'string'
      AND sign_up_otp_context->>'surface' = 'app'
      AND sign_up_otp_context->>'purpose' = 'sign_up'
      AND sign_up_otp_context->>'flow_ref' ~ '^[A-Za-z0-9_-]{1,21}$'
      AND sign_up_otp_context->>'owner_ref' ~ '^[A-Za-z0-9_-]{1,21}$'
      AND sign_up_otp_context->>'contact_ref' = public_id
      AND sign_up_otp_context->>'nonce_digest' ~ '^[0-9a-f]{64}$'
      AND sign_up_otp_context->>'destination_digest' ~ '^[0-9a-f]{64}$'
      AND sign_up_otp_context->>'code_digest' ~ '^[0-9a-f]{64}$'
      AND sign_up_otp_context->>'counter' ~ '^(0|[1-9][0-9]{0,19})$'
      AND (sign_up_otp_context->>'counter')::numeric <= 18446744073709551615
      AND (sign_up_otp_context->>'issued_at')::timestamptz < (sign_up_otp_context->>'expires_at')::timestamptz
      AND (
        (sign_up_otp_context->'verified_at' = 'null'::jsonb AND sign_up_otp_context->'result_expires_at' = 'null'::jsonb)
        OR (
          jsonb_typeof(sign_up_otp_context->'verified_at') = 'string'
          AND jsonb_typeof(sign_up_otp_context->'result_expires_at') = 'string'
          AND (sign_up_otp_context->>'issued_at')::timestamptz <= (sign_up_otp_context->>'verified_at')::timestamptz
          AND (sign_up_otp_context->>'verified_at')::timestamptz < (sign_up_otp_context->>'expires_at')::timestamptz
          AND (sign_up_otp_context->>'verified_at')::timestamptz < (sign_up_otp_context->>'result_expires_at')::timestamptz
          AND (sign_up_otp_context->>'result_expires_at')::timestamptz <= (sign_up_otp_context->>'verified_at')::timestamptz + interval '60 seconds'
        )
      )
    ) IS TRUE
  SQL
  private_constant :CONTEXT_SHAPE

  def up
    TABLES.each do |table|
      add_check_constraint(
        table,
        CONTEXT_SHAPE,
        name: "#{table}_sign_up_otp_context_shape", validate: false,
      )
      validate_check_constraint(table, name: "#{table}_sign_up_otp_context_shape")
    end

    # Owner-approved bounded DDL; no existing Contact or proof facts are rewritten.
    safety_assured do
      execute(<<~SQL.squish)
        CREATE FUNCTION enforce_client_sign_up_otp_proof() RETURNS trigger
        LANGUAGE plpgsql AS $$
        BEGIN
          IF OLD.sign_up_otp_context->>'verified_at' IS NOT NULL AND
             NEW.sign_up_otp_context IS DISTINCT FROM OLD.sign_up_otp_context THEN
            RAISE EXCEPTION 'committed signup OTP proof is immutable';
          END IF;
          RETURN NEW;
        END;
        $$;
      SQL
      TABLES.each do |table|
        execute(<<~SQL.squish)
          CREATE TRIGGER #{table}_sign_up_otp_proof_trigger
          BEFORE UPDATE OF sign_up_otp_context ON #{table}
          FOR EACH ROW EXECUTE FUNCTION enforce_client_sign_up_otp_proof();
        SQL
      end
    end
  end

  def down
    safety_assured do
      TABLES.each do |table|
        execute("DROP TRIGGER #{table}_sign_up_otp_proof_trigger ON #{table}")
      end
      execute("DROP FUNCTION enforce_client_sign_up_otp_proof()")
    end
    TABLES.each do |table|
      remove_check_constraint(table, name: "#{table}_sign_up_otp_context_shape")
    end
  end
end
