# typed: false
# frozen_string_literal: true

# The one OP authority-stop primitive (BX-1, D-119; two.md 5.8 v2, D-172, D-173).
#
# Every revocation of an OP root or grant goes through here. In one transaction of the realm OP
# database (joined when the caller already holds one) it records the stop with its cause, scope and
# principal, revokes the targets under the Device Session -> root -> grant lock order that every
# issuance path takes, and writes the target rows, an epoch cutoff child for principal-wide stops,
# one durable Back-Channel Logout participant row per revoked grant (D-117) and, for a browser
# logout, the browser-bound one-time receipt. After the commit the outbox job is enqueued (D-121).
#
# A re-run with the same idempotency key returns the stored stop and revokes or notifies nothing
# again (D-123). A legacy-revoked root with live grants is repaired by recording those grant stops
# and durable participants together with the root target.
class OpAuthorityStopCommitter
  class Refused < StandardError; end

  Result =
    Data.define(:stop, :replayed, :receipt_nonce) do
      def replayed? = replayed

      def stopped? = !stop.nil?
    end

  REALMS = {
    "app" => {
      stop: OpAppAuthorityStop,
      root_target: OpAppAuthorityStopRootTarget,
      grant_target: OpAppAuthorityStopGrantTarget,
      epoch_cutoff: OpAppAuthorityStopEpochCutoff,
      participant: OpAppAuthorityStopParticipant,
      browser_logout: OpAppAuthorityStopBrowserLogout,
      root: ClientToken,
      grant: OpAppGrant,
      device: ClientDeviceSession,
      root_key: :client_token_id,
      resource_type: "client",
    },
    "com" => {
      stop: OpComAuthorityStop,
      root_target: OpComAuthorityStopRootTarget,
      grant_target: OpComAuthorityStopGrantTarget,
      epoch_cutoff: OpComAuthorityStopEpochCutoff,
      participant: OpComAuthorityStopParticipant,
      browser_logout: OpComAuthorityStopBrowserLogout,
      root: VisitorToken,
      grant: OpComGrant,
      device: VisitorDeviceSession,
      root_key: :visitor_token_id,
      resource_type: "visitor",
    },
    "org" => {
      stop: OpOrgAuthorityStop,
      root_target: OpOrgAuthorityStopRootTarget,
      grant_target: OpOrgAuthorityStopGrantTarget,
      epoch_cutoff: OpOrgAuthorityStopEpochCutoff,
      participant: OpOrgAuthorityStopParticipant,
      browser_logout: OpOrgAuthorityStopBrowserLogout,
      root: OperatorToken,
      grant: OpOrgGrant,
      device: OperatorDeviceSession,
      root_key: :operator_token_id,
      resource_type: "operator",
    },
  }.freeze
  BROWSER_CAUSES = %w(browser_logout rp_initiated_logout).freeze
  CAUSE_SCOPES = {
    "browser_logout" => %w(root).freeze,
    "rp_initiated_logout" => %w(root).freeze,
    "token_revocation" => %w(grant).freeze,
    "refresh_reuse" => %w(grant).freeze,
    "revoke_others" => %w(root).freeze,
    "credential_change" => %w(root).freeze,
    "identity_stop" => %w(all_roots_of_principal).freeze,
    "administrative" => %w(root all_roots_of_principal).freeze,
    "risk" => %w(root all_roots_of_principal).freeze,
  }.freeze
  RECEIPT_TTL = 10.minutes
  # BX-10: a participant is retried until the grant's absolute expiry plus the longest Access JWT
  # lifetime plus clock skew (D-111: ten minutes and thirty seconds).
  DELIVERY_GRACE = CoreBrowserCredentialContract::ACCESS_TTL + 30.seconds

  class << self
    public

    # A single root and every grant under its Device Session (`root` scope).
    def stop_root(root:, cause:, principal_public_id:, authority_evidence_ref:, browser_binding: nil)
      new(
        realm: realm_for_root(root), cause:, scope: "root", principal_public_id:, authority_evidence_ref:,
        roots: [root], idempotency_key: "root:#{root.public_id}", browser_binding:,
      ).call
    end

    # One grant (refresh family) only; its root is kept (`grant` scope).
    def stop_grant(grant:, cause:, principal_public_id:, authority_evidence_ref:)
      new(
        realm: realm_for_grant(grant), cause:, scope: "grant", principal_public_id:, authority_evidence_ref:,
        grant:, idempotency_key: "grant:#{grant.public_id}",
      ).call
    end

    # Every listed root of one principal, with the epoch cutoff that ended them
    # (`all_roots_of_principal` scope). Zero roots is a valid, recorded stop.
    def stop_principal(realm:, roots:, cause:, principal_public_id:, authority_evidence_ref:, cutoff_epoch:)
      new(
        realm:, cause:, scope: "all_roots_of_principal", principal_public_id:, authority_evidence_ref:,
        roots:, cutoff_epoch:, idempotency_key: "principal:#{principal_public_id}:#{authority_evidence_ref}",
      ).call
    end

    def realm_for_root(root)
      { ClientToken => "app", VisitorToken => "com", OperatorToken => "org" }.fetch(root.class)
    end

    def realm_for_grant(grant)
      { OpAppGrant => "app", OpComGrant => "com", OpOrgGrant => "org" }.fetch(grant.class)
    end

    def stop_class(realm) = REALMS.fetch(realm.to_s).fetch(:stop)

    private :new
  end

  def initialize(realm:, cause:, scope:, principal_public_id:, authority_evidence_ref:, idempotency_key:,
                 roots: [], grant: nil, cutoff_epoch: nil, browser_binding: nil)
    @realm = realm.to_s
    @config = REALMS.fetch(@realm)
    @cause = cause.to_s
    @scope = scope.to_s
    @principal_public_id = principal_public_id.to_s
    @authority_evidence_ref = authority_evidence_ref.to_s
    @idempotency_digest = Digest::SHA256.digest("#{@realm}:#{idempotency_key}")
    @roots = Array(roots)
    @grant = grant
    @cutoff_epoch = cutoff_epoch
    @browser_binding = browser_binding
    validate!
  end

  public

  def call
    result = nil
    stop_class.superclass.connected_to(role: :writing) do
      stop_class.transaction do
        lock_idempotency_key
        existing = stop_class.lock.find_by(realm:, idempotency_digest:)
        result =
          if existing
            Result.new(stop: existing, replayed: true, receipt_nonce: nil)
          else
            commit_stop
          end
      end
    end
    schedule_delivery(result)
    result
  end

  private

  attr_reader :realm, :config, :cause, :scope, :principal_public_id, :authority_evidence_ref, :idempotency_digest,
              :roots, :grant, :cutoff_epoch, :browser_binding

  def validate!
    validate_cause_and_scope!
    validate_authority_evidence!
    validate_scope_arguments!
    validate_target_realms!
    validate_browser_binding!
  end

  def validate_cause_and_scope!
    OpAuthorityStopReference.cause_id(cause)
    OpAuthorityStopReference.scope_id(scope)
    allowed_scopes = CAUSE_SCOPES.fetch(cause)
    return if allowed_scopes.include?(scope)

    raise ArgumentError, "cause #{cause.inspect} requires one of scopes #{allowed_scopes.inspect}"
  end

  def validate_authority_evidence!
    # D-123: a stop without an established principal is refused.
    raise Refused, "authority stop requires an established principal" if principal_public_id.blank?
    raise Refused, "authority stop requires authority evidence" if authority_evidence_ref.blank?
    raise Refused, "authority evidence exceeds 128 characters" if authority_evidence_ref.length > 128
  end

  def validate_scope_arguments!
    case scope
    when "root"
      raise ArgumentError, "a root stop names exactly one root" unless roots.one? && grant.nil?
    when "grant"
      raise ArgumentError, "a grant stop names exactly one grant" unless grant && roots.empty?
    when "all_roots_of_principal"
      raise ArgumentError, "a principal stop needs its epoch cutoff" unless cutoff_epoch.is_a?(Integer)
      raise ArgumentError, "a principal stop names no grant" if grant
    end
    if scope != "all_roots_of_principal" && !cutoff_epoch.nil?
      raise ArgumentError, "only a principal stop carries an epoch cutoff"
    end
    return unless scope == "all_roots_of_principal" && cutoff_epoch < 1

    raise ArgumentError, "a principal stop cutoff must be positive"

  end

  def validate_target_realms!
    roots.each do |root|
      raise ArgumentError,
            "root #{root.class} does not belong to realm #{realm}" unless root.class == config.fetch(:root)
    end
    return unless grant && grant.class != config.fetch(:grant)

    raise ArgumentError, "grant #{grant.class} does not belong to realm #{realm}"

  end

  def validate_browser_binding!
    return if browser_binding.nil?

    raise Refused,
          "browser binding must be a non-empty string" unless browser_binding.is_a?(String) && browser_binding.present?
    return if BROWSER_CAUSES.include?(cause)

    raise ArgumentError, "only a browser logout carries a browser binding"
  end

  def lock_idempotency_key
    high, low = idempotency_digest.unpack("l>l>")
    stop_class.connection_pool.with_connection do |connection|
      connection.execute("DO $$ BEGIN PERFORM pg_advisory_xact_lock(#{high}, #{low}); END $$")
    end
  end

  def commit_stop
    now = stop_class.database_now
    targets = revoke_targets(now)
    return Result.new(stop: nil, replayed: false, receipt_nonce: nil) unless targets

    revoked_roots, revoked_grants = targets
    if scope == "root" && revoked_roots.empty?
      return Result.new(stop: nil, replayed: false, receipt_nonce: nil)
    end

    persist_stop!(now:, revoked_roots:, revoked_grants:)
  end

  def revoke_targets(now)
    (scope == "grant") ? revoke_grant_target(now) : revoke_root_targets(now)
  end

  def revoke_grant_target(now)
    locked = lock_grant_chain(grant)
    return unless locked

    locked.revoke_under_stop_lock!(status: grant_status, now:)
    [[], [locked]]
  end

  def revoke_root_targets(now)
    revoked_roots = []
    revoked_grants = []
    roots.sort_by(&:id).each do |root|
      locked_root, grants = lock_root_chain(root)
      next unless locked_root

      grants.each { |live| live.revoke_under_stop_lock!(status: grant_status, now:) }
      locked_root.revoke!(now:) unless locked_root.revoked?
      revoked_roots << locked_root
      revoked_grants.concat(grants)
    end
    [revoked_roots, revoked_grants]
  end

  def persist_stop!(now:, revoked_roots:, revoked_grants:)
    stop = stop_class.create!(
      public_id: PublicId.generate, realm:, cause_id: OpAuthorityStopReference.cause_id(cause),
      scope_id: OpAuthorityStopReference.scope_id(scope), principal_public_id:,
      authority_evidence_ref:, idempotency_digest:, occurred_at: now,
    )
    revoked_roots.each { |root| model(:RootTarget).create!(stop:, root:) }
    revoked_grants.each { |live| model(:GrantTarget).create!(stop:, grant: live) }
    model(:EpochCutoff).create!(stop:, cutoff_epoch:) if scope == "all_roots_of_principal"
    revoked_grants.each { |live| record_participant!(stop, live, now) }
    Result.new(stop:, replayed: false, receipt_nonce: browser_binding ? issue_receipt!(stop, now) : nil)
  end

  # Device Session -> root -> grants (id order); the order of RpSession#with_parent_and_self_lock.
  def lock_root_chain(root)
    config.fetch(:device).lock.find(root.device_session_id)
    locked_root = config.fetch(:root).lock.find(root.id)

    live = config.fetch(:grant).where(revoked_at: nil)
    scope_rows = live.where(config.fetch(:root_key) => locked_root.id)
    scope_rows = scope_rows.or(live.where(device_session_id: locked_root.device_session_id)) if
      locked_root.device_session_id
    grants = scope_rows.order(:id).lock.to_a
    return [nil, []] if locked_root.revoked? && grants.empty?

    [locked_root, grants]
  end

  def lock_grant_chain(target)
    config.fetch(:device).lock.find(target.device_session_id)
    root_id = grant_root_id(target)
    raise ActiveRecord::RecordNotFound, "authority-stop grant has no root" unless root_id

    config.fetch(:root).lock.find(root_id)
    locked = config.fetch(:grant).lock.find(target.id)
    locked.revoked_at.nil? ? locked : nil
  end

  def grant_root_id(target)
    case target
    when OpAppGrant then target.client_token_id
    when OpComGrant then target.visitor_token_id
    when OpOrgGrant then target.operator_token_id
    else raise ArgumentError, "unsupported authority-stop grant #{target.class}"
    end
  end

  def record_participant!(stop, live, now)
    deadline = [live.refresh_token_expires_at, now].compact.max + DELIVERY_GRACE
    model(:Participant).create!(
      stop:, grant: live, status_id: OpAuthorityStopReference.participant_status_id("pending"),
      issuer: OidcIssuer.for_resource_type(config.fetch(:resource_type)), client_id: live.oidc_client_id,
      sid: live.public_id,
      endpoint_identity: OidcClientStoresStaticClientStore.backchannel_logout_uri(live.oidc_client_id),
      next_attempt_at: now, deadline_at: deadline, lease_expires_at: now, last_outcome: "none",
    )
  end

  # Only the nonce digest is stored; the nonce goes back to the browser once.
  def issue_receipt!(stop, now)
    nonce = SecureRandom.urlsafe_base64(32)
    model(:BrowserLogout).create!(
      stop:, browser_binding_digest: Digest::SHA256.digest(browser_binding.to_s),
      receipt_nonce_digest: Digest::SHA256.digest(nonce), receipt_expires_at: now + RECEIPT_TTL,
      receipt_consumed: false,
    )
    nonce
  end

  def grant_status
    BROWSER_CAUSES.include?(cause) ? "success" : "failed"
  end

  def schedule_delivery(result)
    return unless result.stopped? && !result.replayed?

    # Enqueued after the outermost commit; the recurring sweep covers a lost enqueue (D-121).
    ActiveRecord.after_all_transactions_commit do
      enqueued = OpOutboxDispatchJob.perform_later
      next unless enqueued == false

      Rails.logger.warn(
        JitLogEvent.format("oidc.backchannel_logout.enqueue", realm: result.stop.realm, outcome: "unavailable"),
      )
    end
  end

  def stop_class = config.fetch(:stop)

  def model(suffix)
    case suffix
    when :RootTarget then config.fetch(:root_target)
    when :GrantTarget then config.fetch(:grant_target)
    when :EpochCutoff then config.fetch(:epoch_cutoff)
    when :Participant then config.fetch(:participant)
    when :BrowserLogout then config.fetch(:browser_logout)
    else raise ArgumentError, "unsupported authority-stop child #{suffix.inspect}"
    end
  end
end
