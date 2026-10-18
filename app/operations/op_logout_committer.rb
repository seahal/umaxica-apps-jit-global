# typed: false
# frozen_string_literal: true

# The single realm OP logout commit owner (R5-WU09, one.md sections 6.3/7.6).
#
# In ONE transaction of the realm OP database it locks the stable parent (browser device session)
# and its current root, revokes the root and every Grant under it (which voids their Refresh
# families and delivery receipts), and records the Flow, one Participant per affected RP grant, a
# one-time browser-bound LogoutReceipt and one Outbox row per participant. That commit is the logout:
# no RP acknowledgement is required, and nothing later (Refresh, receipt redelivery, callback) can
# restore the revoked authority. Pending authorization Codes are refused at exchange because their
# bound root is no longer active.
#
# The call is idempotent on (realm, idempotency key): a retry after a lost response rereads the
# committed outcome instead of guessing failure or reviving the root.
class OpLogoutCommitter
  REALMS = {
    "app" => { flow: "OpAppLogoutFlow",
               participant: "OpAppLogoutFlowParticipant",
               receipt: "OpAppLogoutReceipt",
               outbox: "OpAppOutboxEvent",
               grant_key: :client_token_id,
               resource_type: "client", },
    "com" => { flow: "OpComLogoutFlow",
               participant: "OpComLogoutFlowParticipant",
               receipt: "OpComLogoutReceipt",
               outbox: "OpComOutboxEvent",
               grant_key: :visitor_token_id,
               resource_type: "visitor", },
    "org" => { flow: "OpOrgLogoutFlow",
               participant: "OpOrgLogoutFlowParticipant",
               receipt: "OpOrgLogoutReceipt",
               outbox: "OpOrgOutboxEvent",
               grant_key: :operator_token_id,
               resource_type: "operator", },
  }.freeze
  FLOW_TTL = 10.minutes
  RECEIPT_TTL = 10.minutes
  EVENT_TYPE = "backchannel_logout"

  Result =
    Data.define(:flow, :receipt_nonce, :replayed) do
      def replayed? = replayed
    end

  def initialize(realm:, root_token:, idempotency_key:, browser_binding:, audit_ref:)
    @config = REALMS.fetch(realm.to_s)
    @realm = realm.to_s
    @root_token = root_token
    @idempotency_digest = digest(idempotency_key, "idempotency")
    @browser_binding_digest = digest(browser_binding, "browser binding")
    @audit_ref = audit_ref.to_s
  end

  class << self
    public

    def call(...) = new(...).call

    def realm_for(root_token)
      { ClientToken => "app", VisitorToken => "com", OperatorToken => "org" }.fetch(root_token.class)
    end
  end

  public

  def call
    flow_class.transaction do
      existing = flow_class.lock.find_by(realm:, idempotency_digest:)
      next Result.new(flow: existing, receipt_nonce: nil, replayed: true) if existing

      # Lock the stable parent first (device session -> root -> grants), as every OP writer does.
      device_session_class = { ClientToken => ClientDeviceSession,
                               VisitorToken => VisitorDeviceSession,
                               OperatorToken => OperatorDeviceSession, }.fetch(root_token.class)
      device_session_class.lock.find(root_token.device_session_id)
      root = root_token.class.lock.find(root_token.id)
      now = flow_class.database_now
      grants = grant_class.lock.where(config.fetch(:grant_key) => root.id).to_a

      root.revoke!(now:) unless root.revoked?
      # "success": the OP commit itself is the successful logout, independent of RP delivery.
      grants.each { |grant| grant.revoke!(status: "success", now:) if grant.revoked_at.nil? }

      flow = flow_class.create!(
        public_id: PublicId.generate, realm:, target_root_ref: root.public_id, idempotency_digest:,
        browser_binding_digest:, expires_at: now + FLOW_TTL, op_revoked_at: now, audit_ref:,
      )
      grants.each { |grant| record_participant!(flow, grant, now) }
      Result.new(flow:, receipt_nonce: issue_receipt!(flow, now), replayed: false)
    end
  end

  private

  attr_reader :config, :realm, :root_token, :idempotency_digest, :browser_binding_digest, :audit_ref

  # The browser-bound receipt; only its digest is stored, the nonce goes back to the browser once.
  def issue_receipt!(flow, now)
    nonce = SecureRandom.urlsafe_base64(32)
    receipt_class.create!(
      logout_flow: flow, public_id: PublicId.generate, nonce_digest: Digest::SHA256.digest(nonce),
      browser_binding_digest:, expires_at: now + RECEIPT_TTL,
    )
    nonce
  end

  def record_participant!(flow, grant, now)
    endpoint = OidcClientStoresStaticClientStore.backchannel_logout_uri(grant.oidc_client_id)
    participant = participant_class.create!(
      logout_flow: flow, issuer: OidcIssuer.for_resource_type(config.fetch(:resource_type)), realm:,
      client_id: grant.oidc_client_id, sid: grant.public_id, endpoint_identity: endpoint, next_attempt_at: now,
    )
    outbox_class.create!(
      event_id: SecureRandom.uuid, logout_flow_participant: participant, event_type: EVENT_TYPE, target_realm: realm,
      target_client_id: grant.oidc_client_id, target_endpoint_identity: endpoint,
      stable_event_ref: "#{flow.public_id}:#{grant.public_id}", next_attempt_at: now,
    )
  end

  def digest(value, label)
    raise ArgumentError, "#{label} is required" unless value.is_a?(String) && value.present?

    Digest::SHA256.digest(value)
  end

  def grant_class = { "app" => OpAppGrant, "com" => OpComGrant, "org" => OpOrgGrant }.fetch(realm)

  def flow_class = config.fetch(:flow).constantize

  def participant_class = config.fetch(:participant).constantize

  def receipt_class = config.fetch(:receipt).constantize

  def outbox_class = config.fetch(:outbox).constantize
end
