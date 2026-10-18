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
      )
    end
  end

  def self.tokens_for(resource)
    case resource
    when ::Client
      ::ClientToken.where(user_id: resource.id)
    when ::Operator
      ::OperatorToken.where(staff_id: resource.id)
    when ::Visitor
      ::VisitorToken.where(visitor_id: resource.id)
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

    matching_or_unattributed.or(scope.where(last_step_up_method: "totp"))
  end
end
