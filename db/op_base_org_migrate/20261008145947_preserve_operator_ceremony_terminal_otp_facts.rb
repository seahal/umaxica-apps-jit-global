# frozen_string_literal: true

class PreserveOperatorCeremonyTerminalOtpFacts < ActiveRecord::Migration[8.2]
  CHANNELS = {
    email: %w(email_candidate_ref normalized_email_digest bootstrap_ceremony_transaction_ref),
    telephone: %w(telephone_candidate_ref normalized_number_digest),
  }.freeze
  PROOF_FIELDS = %w(
    purpose otp_generation otp_verifier otp_expires_at otp_consumed_at otp_cancelled_at
    otp_receipt_verifier otp_result_expires_at surface transaction_id actor_ref session_ref
    operation expires_at
  ).freeze

  def up
    safety_assured do
      CHANNELS.each do |channel, binding_fields|
        fields = PROOF_FIELDS + binding_fields
        new_fields = fields.map { |field| "NEW.#{field}" }.join(", ")
        old_fields = fields.map { |field| "OLD.#{field}" }.join(", ")
        execute(<<~SQL.squish)
          CREATE FUNCTION enforce_operator_#{channel}_terminal_otp_facts() RETURNS trigger
          LANGUAGE plpgsql AS $$
          BEGIN
            IF (OLD.otp_consumed_at IS NOT NULL OR OLD.otp_cancelled_at IS NOT NULL)
               AND ROW(#{new_fields}) IS DISTINCT FROM ROW(#{old_fields}) THEN
              RAISE EXCEPTION 'terminal OTP facts are immutable';
            END IF;
            RETURN NEW;
          END;
          $$;
        SQL
        execute(<<~SQL.squish)
          CREATE TRIGGER operator_#{channel}_terminal_otp_facts
          BEFORE UPDATE ON operator_#{channel}_ceremony_transactions
          FOR EACH ROW EXECUTE FUNCTION enforce_operator_#{channel}_terminal_otp_facts();
        SQL
      end
    end
  end

  def down
    safety_assured do
      CHANNELS.each_key do |channel|
        execute("DROP TRIGGER operator_#{channel}_terminal_otp_facts ON operator_#{channel}_ceremony_transactions")
        execute("DROP FUNCTION enforce_operator_#{channel}_terminal_otp_facts()")
      end
    end
  end
end
