# typed: false
# frozen_string_literal: true

class StepUpResolver
  DEFAULT_TTL = StepUpRequirement::DEFAULT_TTL

  def self.call(token:, requirement: nil, scope: nil, allowed_methods: nil,
                session_binding: nil, token_binding: nil, now: Time.current, ttl: DEFAULT_TTL,
                require_session_binding: true, phishing_resistant_required: false,
                user_verification_required: false, full_reauthentication_required: false,
                purpose: "step_up", audience: "step_up:resolver", actor_ref: "resolver",
                resource_ref: nil, tenant_ref: nil, step_up_required: true,
                # @deprecated Legacy AAL demands are refused and never authorize a result.
                required_aal: nil)
    unless required_aal.blank? || required_aal.to_s == StepUpRequirement::NO_AAL
      raise StepUpRequirement::Invalid, "legacy AAL requirements are unsupported"
    end

    requirement ||= StepUpRequirement.new(
      step_up_required: step_up_required,
      scope: scope,
      allowed_methods: allowed_methods || StepUpRequirement::DEFAULT_ALLOWED_METHODS,
      phishing_resistant_required: phishing_resistant_required,
      user_verification_required: user_verification_required,
      full_reauthentication_required: full_reauthentication_required,
      session_binding: session_binding || token&.public_id,
      token_binding: token_binding || token&.public_id,
      ttl: ttl,
      purpose: purpose,
      audience: audience,
      require_session_binding: require_session_binding,
      actor_ref: actor_ref,
      resource_ref: resource_ref,
      tenant_ref: tenant_ref,
    )
    requirement = StepUpRequirement.build(requirement)
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
      required_aal: nil,
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
      phishing_resistant_required: requirement.phishing_resistant_required?,
      user_verification_required: requirement.user_verification_required?,
      full_reauthentication_required: requirement.full_reauthentication_required?,
      resource_bound: resource_bound?,
      tenant_bound: tenant_bound?,
    )
  end

  private

  attr_reader :token, :requirement, :now

  def satisfied?
    # An Emergency (Restricted Mode) session is not eligible to perform
    # Step-Up-protected operations at all. This is an authentication-context
    # decision, not a freshness one, so it precedes every freshness check.
    return true unless requirement.step_up_required?
    return false if emergency_authentication_context?

    usable_token? &&
      evidence_complete? &&
      satisfied_at.present? &&
      satisfied_at <= now &&
      expires_at.present? &&
      expires_at > now &&
      scope_matches? &&
      method_matches? &&
      phishing_resistance_matches? &&
      user_verification_matches? &&
      full_reauthentication_matches? &&
      session_bound? &&
      token_bound? &&
      purpose_bound? &&
      audience_bound? &&
      resource_bound? &&
      tenant_bound?
  end

  def usable_token?
    token.present? && token.currently_usable?(now)
  end

  def emergency_authentication_context?
    token.respond_to?(:emergency_authentication_context?) && token.emergency_authentication_context?
  end

  def satisfied_at
    token&.last_step_up_at
  end

  def expires_at
    satisfied_at + requirement.ttl if satisfied_at.present? && requirement.ttl
  end

  def scope_matches?
    requirement.scope.present? && token_attribute(:last_step_up_scope) == requirement.scope
  end

  def method_matches?
    requirement.method_allowed?(step_up_method)
  end

  def phishing_resistance_matches?
    evidence = token_attribute(:last_step_up_phishing_resistant)
    [true, false].include?(evidence) && (!requirement.phishing_resistant_required? || evidence)
  end

  def user_verification_matches?
    evidence = token_attribute(:last_step_up_user_verified)
    [true, false].include?(evidence) && (!requirement.user_verification_required? || evidence)
  end

  def full_reauthentication_matches?
    evidence = token_attribute(:last_step_up_full_reauthentication)
    [true, false].include?(evidence) && (!requirement.full_reauthentication_required? || evidence)
  end

  def evidence_complete?
    credential = token_attribute(:last_step_up_credential_ref)
    credential.is_a?(String) && credential.present? &&
      [true, false].include?(token_attribute(:last_step_up_phishing_resistant)) &&
      [true, false].include?(token_attribute(:last_step_up_user_verified)) &&
      [true, false].include?(token_attribute(:last_step_up_full_reauthentication))
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
    return false if expected.blank?

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

  def resource_bound?
    token_attribute(:last_step_up_resource_ref).to_s == requirement.resource_ref.to_s
  end

  def tenant_bound?
    token_attribute(:last_step_up_tenant_ref).to_s == requirement.tenant_ref.to_s
  end

  def token_attribute(name)
    return unless token&.respond_to?(:has_attribute?) && token.has_attribute?(name.to_s)

    token.public_send(name)
  end
end
