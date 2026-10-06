# typed: false
# frozen_string_literal: true

class PostAuthenticationRoutingResolver
  Decision = Data.define(:kind, :target)

  def self.call(flow:, default_path:, oidc_continuation: nil, rp_continuation: nil)
    new(
      flow: flow,
      default_path: default_path,
      oidc_continuation: oidc_continuation,
      rp_continuation: rp_continuation,
    ).call
  end

  def initialize(flow:, default_path:, oidc_continuation:, rp_continuation:)
    @flow = flow
    @default_path = default_path
    @oidc_continuation = oidc_continuation
    @rp_continuation = rp_continuation
  end

  def call
    raise ArgumentError, "post-auth routing requires a completed sign-in flow" unless flow.sign_in_completed?

    return validated_continuation(:oidc_continuation, oidc_continuation) if oidc_continuation.present?
    return validated_continuation(:rp_continuation, rp_continuation) if rp_continuation.present?

    return signed_return_decision if flow.return_to.present?

    dashboard_decision
  end

  private

  attr_reader :flow, :default_path, :oidc_continuation, :rp_continuation

  def signed_return_decision
    result = RedirectsPathTargetResolver.call(flow.return_to, source: :sign_in_flow_return)
    return Decision.new(kind: :signed_return, target: result.value) if result.ok?

    dashboard_decision
  end

  def dashboard_decision
    Decision.new(kind: :dashboard, target: validated_path!(default_path, source: :post_auth_dashboard))
  end

  def validated_continuation(kind, target)
    Decision.new(kind: kind, target: validated_path!(target, source: kind))
  end

  def validated_path!(target, source:)
    result = RedirectsPathTargetResolver.call(target, source: source)
    return result.value if result.ok?

    raise ArgumentError, "post-auth continuation is not a safe internal path"
  end
end
