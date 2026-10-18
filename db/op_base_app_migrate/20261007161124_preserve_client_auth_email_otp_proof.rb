# frozen_string_literal: true

# The owner explicitly approved this bounded SQL DDL; it changes no existing proof data.
class PreserveClientAuthEmailOtpProof < ActiveRecord::Migration[8.2]
  def up
    # Reviewed, owner-approved function/trigger DDL only; no data rewrite.
    safety_assured do
      execute(<<~SQL.squish)
        CREATE FUNCTION enforce_client_auth_email_otp_proof() RETURNS trigger
        LANGUAGE plpgsql AS $$
        BEGIN
          IF OLD.email_otp_context->>'verified_at' IS NOT NULL AND
             NEW.email_otp_context IS DISTINCT FROM OLD.email_otp_context THEN
            RAISE EXCEPTION 'committed email OTP proof is immutable';
          END IF;
          RETURN NEW;
        END;
        $$;
      SQL
      execute(<<~SQL.squish)
        CREATE TRIGGER client_auth_email_otp_proof_trigger
        BEFORE UPDATE OF email_otp_context ON client_auth_ceremony_sessions
        FOR EACH ROW EXECUTE FUNCTION enforce_client_auth_email_otp_proof();
      SQL
    end
  end

  def down
    safety_assured do
      execute("DROP TRIGGER client_auth_email_otp_proof_trigger ON client_auth_ceremony_sessions")
      execute("DROP FUNCTION enforce_client_auth_email_otp_proof()")
    end
  end
end
