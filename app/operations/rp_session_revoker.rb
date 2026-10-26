# typed: false
# frozen_string_literal: true

# Explicit revoke scopes for the Identity -> Base Browser Session -> RP Session hierarchy, each an
# OP authority stop through the one primitive (BX-1, two.md 5.8 v2). A child (grant) stop ends
# refresh and new issuance for that RP only; it does not invalidate sibling RP Sessions or
# already-issued Access JWTs.
class RpSessionRevoker < ApplicationService
  Result =
    Data.define(:success, :revoked_count) do
      def success? = success
    end

  public

  def initialize(scope:, record:, cause:, authority_evidence_ref:)
    super()
    @scope = scope.to_sym
    @record = record
    @cause = cause
    @authority_evidence_ref = authority_evidence_ref
  end

  def call
    count =
      case scope
      when :rp_session then stop_grant(record)
      when :browser_session then stop_root(record)
      when :identity then stop_roots(record)
      else raise ArgumentError, "unsupported RP Session revoke scope: #{scope.inspect}"
      end

    Result.new(success: true, revoked_count: count)
  end

  private

  attr_reader :scope, :record, :cause, :authority_evidence_ref

  # The Browser Session's root and every grant under it, as one `root` stop.
  def stop_root(root)
    unless [ClientToken, VisitorToken, OperatorToken].include?(root.class)
      raise ArgumentError, "unsupported Base Browser Session class: #{root.class.name}"
    end
    return 0 if root.revoked?

    grant_count =
      OpAuthorityStopCommitter::REALMS.fetch(OpAuthorityStopCommitter.realm_for_root(root))
        .then { |config| config.fetch(:grant).where(:revoked_at => nil, config.fetch(:root_key) => root.id).count }
    OpAuthorityStopCommitter.stop_root(
      root:, cause:, principal_public_id: root.actor_record&.public_id.to_s, authority_evidence_ref:,
    )
    grant_count
  end

  def stop_roots(roots)
    raise ArgumentError,
          "identity revoke requires an enumerable of Base Browser Sessions" unless roots.respond_to?(:each)

    roots.sum { |root| stop_root(root) }
  end

  def stop_grant(grant)
    return 0 if grant.blank? || grant.revoked?

    root = grant.parent_token
    principal = root&.actor_record
    result = OpAuthorityStopCommitter.stop_grant(
      grant:, cause:, principal_public_id: principal&.public_id.to_s, authority_evidence_ref:,
    )
    (result.stopped? && !result.replayed?) ? 1 : 0
  end
end
