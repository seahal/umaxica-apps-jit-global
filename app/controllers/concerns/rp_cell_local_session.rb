# typed: false
# frozen_string_literal: true

# Local principal/session authentication for an RP cell process (R5-WU17, one.md section 7.4).
#
# A process booted with an `rp-*` runtime role authenticates only from its own cell: the Access JWT
# verified against the OP's public JWKS plus the opaque local session cookie bound to it
# (RpRequestAuthenticator). It never reads the OP store or the canonical actor. The callback commits
# the verified (issuer, subject, sid) into the cell store (RpCallbackCommitter).
#
# The shared transitional role keeps the pre-R5 OP-chain path; RuntimeRole::SHARED records that
# exit condition (R5-WU19 cell activation). The Base OP role keeps it permanently: it is the OP.
module RpCellLocalSession
  extend ActiveSupport::Concern

  # An HTTPS owner the cell depends on for this request did not answer; fail the request rather
  # than guess the actor's context (same stance as the dashboard identity read).
  class OwnerUnavailable < StandardError; end

  # Public signing keys of each realm OP, cached per process (not request state): one fetch per
  # issuer per OidcOpJwksClient::CACHE_TTL instead of one per request.
  JWKS_CLIENTS = Concurrent::Map.new

  private

  # Only an `rp-*` process is a cell. The shared transitional role and the Base OP role (which
  # serves the identity/credential pages on the same host) keep the OP-chain path.
  def rp_cell_process?
    RuntimeRole::RP_ROLES.include?(RuntimeRole.current)
  end

  def rp_cell
    RpCellBinding.for_client(rp_cell_client_id)
  end

  # The release epoch this cell was deployed for; trusted local configuration, never an OP read.
  def rp_cell_contract_epoch
    ContractEpochValue.coerce(ENV.fetch("UMAXICA_RP_CONTRACT_EPOCH"))
  end

  def rp_cell_issuer
    OidcIssuer.for_resource_type(rp_cell_resource_type)
  end

  def rp_cell_jwks_client
    JWKS_CLIENTS.compute_if_absent(rp_cell_resource_type.to_s) do
      OidcOpJwksClient.for_resource_type(rp_cell_resource_type)
    end
  end

  def authenticate_rp_cell_request(access_token:)
    RpRequestAuthenticator.call(
      cell: rp_cell, access_token:,
      local_session_id: cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE],
      issuer: rp_cell_issuer, contract_epoch: rp_cell_contract_epoch, jwks_client: rp_cell_jwks_client,
    )
  end

  # Commits the verified ID Token into the cell store and installs the local session cookie.
  def commit_rp_cell_callback!(id_token_payload, absolute_expires_at:)
    cell = rp_cell
    # The callback is a GET (reading role by default); the commit is a write on the cell writer.
    result =
      "#{cell.record_prefix}Record".constantize.connected_to(role: :writing) do
        RpCallbackCommitter.call(
          cell:, issuer: id_token_payload.fetch("iss"), subject: id_token_payload.fetch("sub"),
          sid: id_token_payload.fetch("sid"), absolute_expires_at:, contract_epoch: rp_cell_contract_epoch,
        )
      end
    return result unless result.success?

    cookies[OidcRpBrowserCredentialContract::SESSION_COOKIE] =
      OidcRpBrowserCredentialContract.session_cookie_options(expires_at: absolute_expires_at).merge(
        value: result.session.public_id,
      )
    result
  end

  def clear_rp_cell_session_cookie!
    cookies.delete(
      OidcRpBrowserCredentialContract::SESSION_COOKIE,
      OidcRpBrowserCredentialContract.session_cookie_deletion_options,
    )
  end
end
