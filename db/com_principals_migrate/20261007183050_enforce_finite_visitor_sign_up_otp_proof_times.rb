# frozen_string_literal: true

class EnforceFiniteVisitorSignUpOtpProofTimes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  TABLES = %i(visitor_emails visitor_telephones).freeze

  def up
    TABLES.each do |table|
      add_check_constraint(
        table,
        <<~SQL.squish,
          sign_up_otp_context IS NULL OR (
            isfinite((sign_up_otp_context->>'issued_at')::timestamptz)
            AND isfinite((sign_up_otp_context->>'expires_at')::timestamptz)
            AND sign_up_otp_context->>'issued_at' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{6}Z$'
            AND sign_up_otp_context->>'expires_at' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{6}Z$'
            AND (
              sign_up_otp_context->'verified_at' = 'null'::jsonb OR (
                isfinite((sign_up_otp_context->>'verified_at')::timestamptz)
                AND isfinite((sign_up_otp_context->>'result_expires_at')::timestamptz)
                AND sign_up_otp_context->>'verified_at' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{6}Z$'
                AND sign_up_otp_context->>'result_expires_at' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{6}Z$'
              )
            )
          ) IS TRUE
        SQL
        name: "#{table}_sign_up_otp_times_finite", validate: false,
      )
      validate_check_constraint(table, name: "#{table}_sign_up_otp_times_finite")
    end
  end

  def down
    TABLES.each do |table|
      remove_check_constraint(table, name: "#{table}_sign_up_otp_times_finite")
    end
  end
end
