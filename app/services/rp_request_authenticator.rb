# typed: false
# frozen_string_literal: true

# Authenticates one RP request from its own cell state only (R5-WU07, one.md section 7.4).
#
# A request is authenticated when BOTH hold:
# - the Access JWT verifies against the OP's public JWKS for this exact client (issuer, audience,
#   client_id, realm, contract epoch, expiry, authentication context), and
# - the opaque local session cookie names a live session in this cell's store whose OP binding is
#   unrevoked, carries the token's `sid`, and is bound to the token's subject.
#
# Reads go to the cell writer: a stale replica must never authorize a revoked session. There is no
# fallback to the OP root chain or to the Global actor; the result is a local principal.
class RpRequestAuthenticator
  Result =
    Data.define(:status, :principal, :session, :payload) do
      def authenticated? = status == :authenticated
    end

  # authenticated  - both credentials are valid and bound to each other.
  # missing        - no Access JWT or no local session cookie was presented.
  # invalid        - a credential failed verification or does not match the other one.
  STATUSES = %i(authenticated missing invalid).freeze

  def initialize(cell:, access_token:, local_session_id:, issuer:, contract_epoch:, jwks_client:)
    @cell = cell
    @access_token = access_token
    @local_session_id = local_session_id
    @issuer = issuer
    @contract_epoch = contract_epoch
    @jwks_client = jwks_client
  end

  class << self
    public

    def call(...) = new(...).call
  end

  public

  def call
    return result(:missing) if access_token.blank? || local_session_id.blank?

    verification = OidcOpAccessTokenVerifier.new(
      access_token:, client_id: cell.client_id, realm: cell.realm, issuer:, audience: cell.client_id,
      contract_epoch:, jwks_client:,
    ).call
    return result(:invalid) unless verification.success?

    payload = verification.payload
    record_class.connected_to(role: :writing) do
      session = writer_session
      next result(:invalid) unless bound?(session, payload)

      Result.new(
        status: :authenticated, principal: session.op_session_binding.identity_binding.principal,
        session:, payload:,
      )
    end
  end

  private

  attr_reader :cell, :access_token, :local_session_id, :issuer, :contract_epoch, :jwks_client

  def writer_session
    record_class.uncached do
      model(:Session).includes(op_session_binding: { identity_binding: :principal })
        .find_by(public_id: local_session_id.to_s)
    end
  end

  def bound?(session, payload)
    return false unless session&.active?(now: record_class.database_now)
    return false unless session.contract_epoch == payload.fetch("umx_contract_epoch")

    anchor = session.op_session_binding
    identity = anchor.identity_binding
    return false unless identity && identity.principal.disabled_at.nil?
    return false unless secure_equal?(anchor.sid, payload.fetch("sid"))
    return false unless anchor.issuer == payload.fetch("iss")

    secure_equal?(identity.subject, payload.fetch("sub"))
  end

  def secure_equal?(expected, actual)
    expected = expected.to_s
    actual = actual.to_s
    expected.bytesize == actual.bytesize && ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end

  def record_class
    "#{cell.record_prefix}Record".constantize
  end

  def model(suffix)
    "#{cell.record_prefix}#{suffix}".constantize
  end

  def result(status)
    Result.new(status:, principal: nil, session: nil, payload: nil)
  end
end
