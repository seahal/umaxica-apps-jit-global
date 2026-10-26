# typed: false
# frozen_string_literal: true

# RP Refresh over HTTPS under the D-25 standard contract (RFC 6749 section 6, no grace, no receipt).
#
# 1. Check the local session and its OP binding under their row locks, record the installed
#    generation, then commit and release every lock before any network call.
# 2. Dispatch the Refresh once to the OP token endpoint with a fresh endpoint-bound assertion. A lost
#    response is never replayed or resent: the presented credential may already be rotated, so the
#    browser recovers through a new Authorization Code flow (prompt=none first, D-80/D-110).
# 3. Verify the returned Access JWT against the OP public JWKS and this session's sid/subject.
# 4. Install under the session and OP-binding locks again: refuse if the session or binding was
#    revoked meanwhile or another request already advanced the installed generation.
#
# A transport failure before dispatch keeps the browser credentials; a definitive refusal or an
# indeterminate commit clears them.
class RpRefreshCommitter
  Result =
    Data.define(:outcome, :token_response) do
      def installed? = outcome == :installed
    end

  # installed    - this request's tokens are now the session's single installed generation.
  # refused      - the OP definitively refused the credential, or its commit is indeterminate and
  #                the credential may be rotated (clear cookies, new Code Flow).
  # dependency   - the OP could not be reached or answered invalidly; keep cookies, retry later.
  # superseded   - a newer generation was installed meanwhile; keep the current cookies.
  # revoked      - the local session or its OP binding is revoked or expired.
  OUTCOMES = %i(installed refused dependency superseded revoked).freeze
  DISPATCH_BUDGET = 4.0

  def initialize(cell:, local_session_id:, refresh_token:, issuer:, jwks_client:, token_url:)
    @cell = cell
    @local_session_id = local_session_id
    @refresh_token = refresh_token
    @issuer = issuer
    @jwks_client = jwks_client
    @token_url = token_url
  end

  class << self
    public

    def call(...) = new(...).call
  end

  public

  def call
    record_class.connected_to(role: :writing) do
      expected_generation = reserve_generation
      next result(:revoked) unless expected_generation

      @dispatch_deadline = monotonic_now + DISPATCH_BUDGET
      response = dispatch
      next result(response) if response.is_a?(Symbol)

      install(expected_generation, response)
    end
  end

  private

  attr_reader :cell, :local_session_id, :refresh_token, :issuer, :jwks_client, :token_url

  def reserve_generation
    with_locked_session do |session, anchor|
      next unless live?(session, anchor)

      session.installed_generation
    end
  end

  # Returns the token response Hash, or an outcome Symbol when no tokens are available.
  def dispatch
    outcome = OidcOpTokenClient.refresh(
      client_id: cell.client_id, token_url:, refresh_token:, deadline: @dispatch_deadline,
    )
    return outcome.token_response if outcome.success?
    # An indeterminate commit may have rotated the credential at the OP; resending it would present
    # a consumed token and revoke the family (D-25), so the browser starts a new Code Flow instead.
    return :refused if %i(refused indeterminate).include?(outcome.outcome)

    :dependency
  end

  def install(expected_generation, token_response)
    payload = verified_access_payload(token_response)
    return result(:refused) unless payload

    with_locked_session do |session, anchor|
      next result(:revoked) unless live?(session, anchor)
      next result(:refused) unless payload_matches?(session, anchor, payload)
      next result(:superseded) unless session.installed_generation == expected_generation

      session.update!(
        installed_generation: session.installed_generation + 1,
        current_access_jti_digest: Digest::SHA256.hexdigest(payload.fetch("jti")),
        current_access_expires_at: Time.zone.at(payload.fetch("exp")),
      )
      Result.new(outcome: :installed, token_response:)
    end
  end

  def verified_access_payload(token_response)
    verification = OidcOpAccessTokenVerifier.new(
      access_token: token_response[:access_token].to_s, client_id: cell.client_id, realm: cell.realm, issuer:,
      audience: cell.client_id, jwks_client:,
    ).call
    verification.success? ? verification.payload : nil
  end

  def with_locked_session
    record_class.transaction do
      session = model(:Session).find_by(public_id: local_session_id)
      next yield(nil, nil) unless session

      # Callback and logout lock the permanent sid anchor before touching its sessions.
      anchor = model(:OpSessionBinding).includes(identity_binding: :principal).lock.find(session.op_session_binding_id)
      session.lock!
      yield session, anchor
    end
  end

  def live?(session, anchor)
    session && anchor && session.revoked_at.nil? && session.absolute_expires_at > database_now &&
      anchor.revoked_at.nil? && anchor.identity_binding.present? &&
      anchor.identity_binding.principal.disabled_at.nil?
  end

  def payload_matches?(_session, anchor, payload)
    identity = anchor.identity_binding
    anchor.sid == payload.fetch("sid") && anchor.issuer == payload.fetch("iss") &&
      anchor.realm == cell.realm && anchor.client_id == cell.client_id &&
      identity.issuer == anchor.issuer && identity.realm == anchor.realm &&
      identity.client_id == anchor.client_id && identity.subject == payload.fetch("sub")
  end

  def database_now
    record_class.database_now
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def record_class
    "#{cell.record_prefix}Record".constantize
  end

  def model(suffix)
    "#{cell.record_prefix}#{suffix}".constantize
  end

  def result(outcome)
    Result.new(outcome:, token_response: nil)
  end
end
