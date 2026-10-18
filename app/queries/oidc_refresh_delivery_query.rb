# typed: false
# frozen_string_literal: true

# OP-side read-only recovery of an indeterminate RP Refresh (R5-WU08, one.md sections 6.4/7.4).
#
# Request: the original (predecessor) refresh credential, the RP's attempt reference and a fresh
# private_key_jwt assertion whose audience is this exact query endpoint. Answer: the exact response
# stored by that rotation, only while its original five-second receipt is live and only after the
# current actor lifecycle/epoch and grant state are rechecked under the actor-first lock order.
# It never rotates, retries or extends the window; any mismatch is a definitive invalid_grant.
class OidcRefreshDeliveryQuery
  Result =
    Data.define(:token_response, :error) do
      def success? = error.nil?
    end

  class << self
    public

    def call(refresh_token:, attempt_ref:, client_id:, client_assertion:, endpoint_uri:, resource_type:)
      return failure("invalid_client") unless
        OidcClientRegistry.authenticate_assertion(client_id, client_assertion, token_url: endpoint_uri)

      resolved = OidcRefreshTokenIssuer.resolve(refresh_token:, resource_type:)
      return failure("invalid_grant") unless resolved

      root_token = resolved.usage.parent_token
      actor = actor_for(root_token)
      return failure("invalid_grant") unless actor

      result = OidcRefreshTokenIssuer.new(
        refresh_token, client_id:, resource_type:, attempt_ref:, actor_guard: actor_guard(actor, root_token),
      ).query_delivery
      return failure("invalid_grant") unless result.success?

      Result.new(token_response: result.token_response, error: nil)
    rescue RpSession::IssuanceRejected
      failure("invalid_grant")
    end

    private

    def actor_guard(actor, root_token)
      lambda do |&block|
        owner = actor.class
        owner = owner.superclass until owner.connection_class? || owner == ApplicationRecord
        owner.connected_to(role: :writing) do
          actor.with_lock do
            unless actor.active? && root_token.active_status? &&
                AuthenticationEpochValue.root_current?(root_token:, actor:)
              raise RpSession::IssuanceRejected, "actor stopped or epoch advanced"
            end

            block.call
          end
        end
      end
    end

    def actor_for(root_token)
      case root_token
      when ClientToken then Client.find_by(id: root_token.user_id)
      when VisitorToken then Visitor.find_by(id: root_token.visitor_id)
      when OperatorToken then Operator.find_by(id: root_token.staff_id)
      end
    end

    def failure(error)
      Result.new(token_response: nil, error:)
    end
  end
end
