# frozen_string_literal: true

class ValidateClientAuthEmailOtpContext < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_check_constraint(
      :client_auth_ceremony_sessions,
      <<~SQL.squish,
        email_otp_context IS NULL OR (
          jsonb_typeof(email_otp_context) = 'object'
          AND email_otp_context ?& ARRAY[
            'version', 'generation', 'surface', 'purpose', 'sid_digest', 'parent_kind', 'parent_ref',
            'mode', 'contact_ref', 'owner_ref', 'destination_digest', 'binding_fact', 'code_digest',
            'issued_at', 'expires_at', 'verified_at', 'result_expires_at'
          ]
          AND email_otp_context->'version' = '1'::jsonb
          AND email_otp_context->>'generation' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
          AND email_otp_context->>'mode' IN ('real', 'fake')
          AND email_otp_context->>'code_digest' ~ '^[0-9a-f]{64}$'
          AND jsonb_typeof(email_otp_context->'issued_at') = 'string'
          AND jsonb_typeof(email_otp_context->'expires_at') = 'string'
          AND (
            (email_otp_context->'verified_at' = 'null'::jsonb
              AND email_otp_context->'result_expires_at' = 'null'::jsonb)
            OR (jsonb_typeof(email_otp_context->'verified_at') = 'string'
              AND jsonb_typeof(email_otp_context->'result_expires_at') = 'string')
          )
        ) IS TRUE
      SQL
      name: "client_auth_email_otp_context_shape", validate: false,
    )
    validate_check_constraint(:client_auth_ceremony_sessions, name: "client_auth_email_otp_context_shape")
  end

  def down
    remove_check_constraint(:client_auth_ceremony_sessions, name: "client_auth_email_otp_context_shape")
  end
end
