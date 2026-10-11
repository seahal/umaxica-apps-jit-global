# typed: false
# frozen_string_literal: true

Rails.application.config.filter_parameters += %i(
  passw
  email
  telephone
  birthdate
  secret
  credential
  recovery_code
  otp
  token
  jwt
  authorization
  cookie
  _key
  keyset
  jwk
  jwks
  pem
  certificate
  crypt
  salt
  ssn
  cvv
  cvc
  oauth_code
  authorization_code
  code_verifier
  cf-turnstile-response
  turnstile_response
  nonce
  assertion
  entry_ref
  binding_ref
  confirmation_ref
  transaction_ref
  restart_of
  sid
  digest
  result
  social_ceremony_result
  step_up_ceremony_result
  step_up_ceremony_grant
  session_id
  auth_ceremony_session_ref
  auth_email_otp_generation
  sign_up_flow_ref
  sign_up_otp_counter
  contact_ceremony_transaction_ref
  contact_otp_counter
  credential_id
  smtp_password
  aws_ses_smtp_password
)

Rails.application.config.filter_parameters += [
  /\Ader\z/i,
  /\Art\z/i,
  /\Apt\z/i,
  /\Acode\z/i,
  /(?:\A|_)uid\z/i,
  /\Astate\z/i,
]
