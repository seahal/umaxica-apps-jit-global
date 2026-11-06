# frozen_string_literal: true

# Owner-side IAM boundary. The caller must already have authenticated the registered Base ORG
# client and verified the actor's access-token event before invoking the audited commit path.
class OrgIamOwnerMutation
  GRANT_DURATIONS = [7, 30, 90, 180].freeze

  class << self
    public

    def grant(actor:, subject:, token:, evidence:, operation_id:, capability:, duration_days:, reason_code:,
              ticket_id:, request:)
      raise ArgumentError, "unsupported grant duration" unless GRANT_DURATIONS.include?(duration_days)
      raise ArgumentError, "unsupported capability" unless OperatorCapabilityGrant::CAPABILITIES.include?(capability)
      raise ArgumentError, "unsupported grant reason" unless
        OperatorCapabilityGrant::DELEGATED_GRANT_REASON_CODES.include?(reason_code)
      unless ticket_id.nil? || (ticket_id.is_a?(String) && OperatorCapabilityGrant::TICKET_ID_FORMAT.match?(ticket_id))
        raise ArgumentError, "invalid ticket"
      end

      digest = OrgIamRequestDigest.grant(
        actor_public_id: actor.public_id, subject_public_id: subject.public_id, capability:,
        duration_seconds: duration_days.days.to_i, reason_code:, ticket_id:,
      )
      authorize =
        lambda do |locked_actor|
          target = Operator.find(subject.id)
          candidate = OperatorCapabilityGrant.new(operator: target, capability:)
          target.capability_eligible? && OperatorCapabilityGrantPolicy.new(
            candidate,
            user: locked_actor,
          ).apply(:create?)
        end
      OrgIamAuditedCommit.call(
        actor:, subject:, token:, evidence:, operation_id:, operation_kind: "grant", request_digest: digest,
        reason_code:, metadata: { capability:, ticket_id:, subject_public_id: subject.public_id },
        request_id: request.request_id, ip_address: request.remote_ip, user_agent: request.user_agent, authorize:,
      ) do |locked_actor|
        issued = OperatorCapabilityGrant.issue!(
          operator: Operator.find(subject.id), granted_by: locked_actor, capability:, reason_code:, ticket_id:,
          duration: duration_days.days,
        )
        { "grant_public_id" => issued.public_id, "expires_at" => issued.expires_at.iso8601 }
      end
    end

    def revoke(actor:, token:, evidence:, operation_id:, grant:, reason_code:, request:)
      raise ArgumentError, "unsupported revoke reason" unless OperatorCapabilityGrant::REVOKE_REASON_CODES.include?(reason_code)

      subject = Operator.find(grant.operator_id)
      digest = OrgIamRequestDigest.revoke(
        actor_public_id: actor.public_id, subject_public_id: subject.public_id,
        grant_public_id: grant.public_id, reason_code:,
      )
      changed_by_this_call = false
      authorize =
        lambda do |locked_actor|
          current = OperatorCapabilityGrant.lock.find(grant.id)
          policy = OperatorCapabilityGrantPolicy.new(current, user: locked_actor)
          next false unless policy.apply(:index?) && locked_actor.capability?(OperatorCapabilityGrant::IAM_CAPABILITY_REVOKE)
          next policy.apply(:revoke?) unless current.revoked?

          own_change = changed_by_this_call && current.revoked_by_operator_id == locked_actor.id &&
            current.revoke_reason_code == reason_code
          recorded = OrgIamOperationOutcome.find_by(operation_id:)
          exact_replay = recorded && recorded.operation_kind == "revoke" &&
            recorded.actor_public_id == locked_actor.public_id && recorded.subject_public_id == subject.public_id &&
            recorded.request_digest == digest && recorded.result["grant_public_id"] == current.public_id
          own_change || exact_replay
        end
      OrgIamAuditedCommit.call(
        actor:, subject:, token:, evidence:, operation_id:, operation_kind: "revoke", request_digest: digest,
        reason_code:, metadata: { capability: grant.capability,
                                  grant_public_id: grant.public_id,
                                  subject_public_id: subject.public_id, },
        request_id: request.request_id, ip_address: request.remote_ip, user_agent: request.user_agent, authorize:,
      ) do |locked_actor|
        current = OperatorCapabilityGrant.find(grant.id)
        current.revoke!(by: locked_actor, reason_code:)
        changed_by_this_call = true
        { "grant_public_id" => current.public_id }
      end
    end
  end
end
