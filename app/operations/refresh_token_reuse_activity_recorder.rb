# typed: false
# frozen_string_literal: true

class RefreshTokenReuseActivityRecorder
  def self.call(token:, result:)
    new(token, result).call
  end
  public_class_method :call

  public

  def initialize(token, result)
    @token = token
    @result = result
  end

  def call
    audit_class, event_id, actor, surface = audit_target
    return false unless actor

    context = {
      token_family_id: @token.refresh_token_family_id,
      generation: @token.refresh_token_generation,
      surface: surface,
      result: @result,
    }.compact
    AuthenticationAuditWriter.write(audit_class, event_id, resource: actor, actor: actor, context: context)
  end

  private

  def audit_target
    case @token
    when ClientToken
      [
        ClientChronicle,
        ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED,
        @token.association(:user).tap { |owner| owner.reset_scope }.scope.take!,
        "app",
      ]
    when VisitorToken
      [
        ClientChronicle,
        ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED,
        @token.association(:visitor).tap { |owner| owner.reset_scope }.scope.take!,
        "com",
      ]
    when OperatorToken
      [
        OperatorChronicle,
        OperatorChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED,
        @token.association(:staff).tap { |owner| owner.reset_scope }.scope.take!,
        "org",
      ]
    else
      raise ArgumentError, "unsupported refresh token class: #{@token.class.name}"
    end
  end
end
