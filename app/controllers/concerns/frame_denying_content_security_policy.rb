# typed: false
# frozen_string_literal: true

module FrameDenyingContentSecurityPolicy
  extend ActiveSupport::Concern

  private

  # Narrows the application policy instead of writing the header by hand: a hand-written header
  # stops ActionDispatch's CSP middleware from sending the application policy (script-src,
  # object-src, form-action, ...) at all.
  def deny_framing!(form_action_self: false)
    policy = request.content_security_policy.clone
    policy.frame_ancestors(:none)
    policy.form_action(:self) if form_action_self
    request.content_security_policy = policy
  end
end
