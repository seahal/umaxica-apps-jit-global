# typed: false
# frozen_string_literal: true

# Browser-facing authorization-code handle returned by authorize issuance.
# Persistence lives in Valkey::AuthState::AuthorizationCodeStore; this value is
# only the redirect payload (raw code + echo fields).
OidcIssuedAuthorizationCode =
  Data.define(
    :code,
    :redirect_uri,
    :state,
    :resource_type,
    :client_id,
    :nonce,
    :scope,
  )
