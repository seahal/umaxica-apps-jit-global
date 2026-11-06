# typed: false
# frozen_string_literal: true

class AuthenticationSessionRevoker
  def self.revoke_all_for(resource)
    tokens = tokens_for(resource)
    tokens.find_each do |token|
      AuthenticationLogoutCurrentSession.call(
        resource: resource,
        token: token,
        reason: "session_revoke_all",
        cause: "revoke_others", # D-173
      )
    end
  end

  def self.tokens_for(resource)
    case resource
    when ::Client
      ::ClientToken.where(user_id: resource.id)
    when ::Operator
      ::OperatorToken.where(staff_id: resource.id)
    else
      raise ArgumentError, "Unsupported resource type: #{resource.class}"
    end
  end

  # adr/unified-enforcement.md, Session revocation: the union of sessions
  # established by `method`, sessions with no recorded establishing method
  # (always -- not only on the first Authentication Method Effect applied to a
  # principal, so a second effect never behaves differently from the first),
  # and -- only when `method` is "totp" -- every session carrying a TOTP
  # step-up, revoked in full. A session whose elevation rests on a
  # compromised authenticator is itself suspect; effects on other methods
  # never propagate through step-up.
  def self.tokens_for_method(resource, method)
    scope = tokens_for(resource)
    method = method.to_s
    matching_or_unattributed = scope.where(established_authentication_method: [method, nil])
    return matching_or_unattributed unless method == "totp"

    matching_or_unattributed
      .or(scope.where(last_step_up_method: "totp"))
      .or(scope.where(id: latest_totp_commit_root_token_ids(resource)))
  end

  def self.latest_totp_commit_root_token_ids(resource)
    commit_class =
      case resource
      when ::Client then ::ClientStepUpCommit
      when ::Operator then ::OperatorStepUpCommit
      else raise ArgumentError, "Unsupported resource type: #{resource.class}"
      end

    facts = commit_class.arel_table
    later_facts = facts.alias("later_step_up_commits")
    later_timestamp = later_facts[:committed_at].gt(facts[:committed_at])
    same_timestamp_with_later_id = later_facts[:committed_at].eq(facts[:committed_at])
      .and(later_facts[:id].gt(facts[:id]))
    later_fact_exists = commit_class.from(later_facts)
      .where(later_facts[:root_token_id].eq(facts[:root_token_id]))
      .where(later_timestamp.or(same_timestamp_with_later_id))
      .select(1).arel.exists

    commit_class.where(verified_method: "totp")
      .where(Arel::Nodes::Not.new(later_fact_exists))
      .select(:root_token_id)
  end

  private_class_method :latest_totp_commit_root_token_ids
end
