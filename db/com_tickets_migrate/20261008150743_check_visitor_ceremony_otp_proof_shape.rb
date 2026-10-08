# frozen_string_literal: true

class CheckVisitorCeremonyOtpProofShape < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  CHANNELS = {
    email: %w(email_candidate_ref normalized_email_digest),
    telephone: %w(telephone_candidate_ref normalized_number_digest),
  }.freeze

  def change
    CHANNELS.each do |channel, (candidate, digest)|
      table = "visitor_#{channel}_ceremony_transactions"
      add_check_constraint(table, <<~SQL.squish, name: "visitor_#{channel}_otp_proof_shape", validate: false)
        otp_generation IS NULL OR (
          purpose IS NOT NULL AND actor_ref <> '' AND session_ref <> '' AND
          #{candidate} IS NOT NULL AND #{candidate} <> '' AND
          (#{digest} IS NULL OR #{digest} ~ '^[0-9a-f]{64}$') AND
          otp_expires_at IS NOT NULL AND isfinite(otp_expires_at) AND isfinite(expires_at) AND
          (
            (otp_consumed_at IS NULL AND otp_cancelled_at IS NULL AND
             otp_verifier IS NOT NULL AND otp_verifier ~ '^[0-9a-f]{64}$' AND
             otp_receipt_verifier IS NULL AND otp_result_expires_at IS NULL)
            OR
            (otp_consumed_at IS NOT NULL AND isfinite(otp_consumed_at) AND
             otp_consumed_at < otp_expires_at AND otp_cancelled_at IS NULL AND otp_verifier IS NULL AND
             otp_receipt_verifier IS NOT NULL AND otp_result_expires_at IS NOT NULL)
            OR
            (otp_cancelled_at IS NOT NULL AND isfinite(otp_cancelled_at) AND
             otp_consumed_at IS NULL AND otp_verifier IS NULL AND
             otp_receipt_verifier IS NULL AND otp_result_expires_at IS NULL)
          )
        ) IS TRUE
      SQL
      validate_check_constraint(table, name: "visitor_#{channel}_otp_proof_shape")
    end
  end
end
