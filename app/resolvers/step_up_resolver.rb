# typed: false
# frozen_string_literal: true

class StepUpResolver
  DEFAULT_TTL = StepUpRequirement::DEFAULT_TTL
  DEFAULT_REQUIRED_AAL = StepUpRequirement::DEFAULT_AAL

  def self.call(token:, scope: nil, required_aal: DEFAULT_REQUIRED_AAL, allowed_methods: nil,
                session_binding: nil, token_binding: nil, requirement: nil,
                now: Time.current, ttl: DEFAULT_TTL, require_session_binding: false)
    requirement =
      if requirement
        StepUpRequirement.build(requirement)
      else
        StepUpRequirement.build(
          scope,
          required_aal: required_aal,
          allowed_methods: allowed_methods || StepUpRequirement::DEFAULT_ALLOWED_METHODS,
          session_binding: session_binding,
          token_binding: token_binding,
          ttl: ttl,
          require_session_binding: require_session_binding,
        )
      end
    new(token: token, requirement: requirement, now: now).call
  end

  def initialize(token:, requirement:, now:)
    @token = token
    @requirement = requirement
    @now = now
  end

  def call
    Actor::StepUp.new(
      scope: requirement.scope,
      required_aal: requirement.required_aal,
      allowed_methods: requirement.allowed_methods,
      satisfied: satisfied?,
      satisfied_at: satisfied_at,
      expires_at: expires_at,
      usable_token: usable_token?,
      method: step_up_method,
      session_bound: session_bound?,
      token_bound: token_bound?,
      purpose: requirement.purpose,
      audience: requirement.audience,
      purpose_bound: purpose_bound?,
      audience_bound: audience_bound?,
    )
  end

  private

  attr_reader :token, :requirement, :now

  def satisfied?
    # An Emergency (Restricted Mode) session is not eligible to perform
    # Step-Up-protected operations at all. This is an authentication-context
    # decision, not a freshness one, so it precedes every freshness check: a
    # session that somehow carried step-up columns still cannot satisfy a
    # requirement here. See docs/security/org-emergency-access.md.
    return true unless requirement.step_up_required?
    return false if emergency_authentication_context?

    usable_token? &&
      requirement.aal_supported? &&
      satisfied_at.present? &&
      expires_at.present? &&
      expires_at > now &&
      scope_matches? &&
      aal_matches? &&
      method_matches? &&
      session_bound? &&
      token_bound? &&
      purpose_bound? &&
      audience_bound?
  end

  def usable_token?
    token.present? && token.currently_usable?
  end

  def emergency_authentication_context?
    token.respond_to?(:emergency_authentication_context?) && token.emergency_authentication_context?
  end

  def satisfied_at
    token&.last_step_up_at
  end

  def expires_at
    satisfied_at + requirement.ttl if satisfied_at.present?
  end

  def scope_matches?
    requirement.scope.present? && token.last_step_up_scope == requirement.scope
  end

  def aal_matches?
    return true unless requirement.aal_required?

    token_value = token_attribute(:last_step_up_aal)
    return !requirement.aal_required? if token_value.blank?

    token_value.to_s == requirement.required_aal.to_s
  end

  def method_matches?
    requirement.method_allowed?(step_up_method)
  end

  def step_up_method
    token_attribute(:last_step_up_method)
  end

  def session_bound?
    expected = requirement.session_binding
    return false if requirement.require_session_binding && expected.blank?
    return true if expected.blank?

    recorded = token_attribute(:last_step_up_session_public_id)
    recorded.present? && ActiveSupport::SecurityUtils.secure_compare(recorded.to_s, expected.to_s)
  end

  def token_bound?
    expected = requirement.token_binding
    return true if expected.blank?

    token.public_id.present? && ActiveSupport::SecurityUtils.secure_compare(token.public_id.to_s, expected.to_s)
  end

  def purpose_bound?
    expected = requirement.purpose
    return true if expected.blank?

    recorded = token_attribute(:last_step_up_purpose)
    recorded.present? && ActiveSupport::SecurityUtils.secure_compare(recorded.to_s, expected.to_s)
  end

  def audience_bound?
    expected = requirement.audience
    return true if expected.blank?

    recorded = token_attribute(:last_step_up_audience)
    recorded.present? && ActiveSupport::SecurityUtils.secure_compare(recorded.to_s, expected.to_s)
  end

  def token_attribute(name)
    return unless token&.respond_to?(:has_attribute?) && token.has_attribute?(name.to_s)

    token.public_send(name)
  end
end
