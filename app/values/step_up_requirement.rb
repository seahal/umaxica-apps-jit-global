# typed: false
# frozen_string_literal: true

class StepUpRequirement
  class Invalid < ArgumentError; end

  # These names remain only as storage/wire labels while the explicit policy fields below become
  # authoritative. A non-`none` input is rejected rather than translated into a new hierarchy.
  NO_AAL = "none"
  DEFAULT_AAL = nil
  DEFAULT_TTL = 15.minutes
  DEFAULT_ALLOWED_METHODS = %i(totp passkey).freeze
  METHODS = %i(passkey totp email_otp secret_credential).freeze
  PURPOSES = %w(step_up reauthentication bootstrap credential_registration credential_change).freeze
  UNSET = Object.new.freeze

  attr_reader :required_aal, :allowed_methods, :scope, :session_binding,
              :token_binding, :ttl, :purpose, :audience, :require_session_binding,
              :step_up_required, :phishing_resistant_required, :user_verification_required,
              :full_reauthentication_required, :actor_ref, :resource_ref, :tenant_ref

  def self.build(value = nil, **attributes)
    return value if value.is_a?(self)

    if value.is_a?(Hash)
      new(**value.symbolize_keys.merge(attributes))
    else
      new(scope: value, **attributes)
    end
  end

  def initialize(step_up_required: UNSET, required_aal: UNSET,
                 phishing_resistant_required: UNSET, user_verification_required: UNSET,
                 full_reauthentication_required: UNSET, allowed_methods: UNSET, scope: UNSET,
                 session_binding: UNSET, token_binding: UNSET, ttl: UNSET, purpose: UNSET,
                 audience: UNSET, require_session_binding: UNSET, actor_ref: UNSET,
                 resource_ref: UNSET, tenant_ref: UNSET)
    @step_up_required = strict_boolean(step_up_required, :step_up_required)
    @phishing_resistant_required = strict_boolean(phishing_resistant_required, :phishing_resistant_required)
    @user_verification_required = strict_boolean(user_verification_required, :user_verification_required)
    @full_reauthentication_required = strict_boolean(
      full_reauthentication_required, :full_reauthentication_required,
    )
    @required_aal = normalize_legacy_aal(required_aal)
    @allowed_methods = normalize_methods(allowed_methods)
    @scope = normalize_string(scope, :scope)
    @session_binding = normalize_string(session_binding, :session_binding)
    @token_binding = normalize_string(token_binding, :token_binding)
    @ttl = normalize_ttl(ttl)
    @purpose = normalize_string(purpose, :purpose)
    @audience = normalize_string(audience, :audience)
    @require_session_binding = strict_boolean(require_session_binding, :require_session_binding)
    @actor_ref = normalize_string(actor_ref, :actor_ref)
    @resource_ref = normalize_string(resource_ref, :resource_ref)
    @tenant_ref = normalize_string(tenant_ref, :tenant_ref)

    validate_contract!
    freeze
  end

  def step_up_required? = step_up_required

  def phishing_resistant_required? = phishing_resistant_required

  def user_verification_required? = user_verification_required

  def full_reauthentication_required? = full_reauthentication_required

  # Deprecated storage-label compatibility only. This method must never participate in policy.
  # FIXME: remove with the `required_aal` column after the AAL removal ledger is retired.
  def aal_required? = false

  def method_allowed?(method)
    normalized = normalize_method(method)
    normalized.present? && allowed_methods.include?(normalized)
  end

  def to_h
    {
      step_up_required: step_up_required,
      allowed_methods: allowed_methods,
      phishing_resistant_required: phishing_resistant_required,
      user_verification_required: user_verification_required,
      full_reauthentication_required: full_reauthentication_required,
      scope: scope,
      session_binding: session_binding,
      token_binding: token_binding,
      ttl: ttl,
      purpose: purpose,
      audience: audience,
      require_session_binding: require_session_binding,
      actor_ref: actor_ref,
      resource_ref: resource_ref,
      tenant_ref: tenant_ref,
    }
  end

  private

  def validate_contract!
    registration = %w(bootstrap credential_registration).include?(purpose)
    active = step_up_required || registration

    if active
      require_present!(scope, :scope)
      require_present!(allowed_methods, :allowed_methods)
      require_present!(ttl, :ttl)
      require_present!(purpose, :purpose)
      require_present!(audience, :audience)
      require_present!(session_binding, :session_binding)
      require_present!(token_binding, :token_binding)
      require_present!(actor_ref, :actor_ref)
      require_present!(resource_ref, :resource_ref, allow_nil: true)
      require_present!(tenant_ref, :tenant_ref, allow_nil: true)
      raise Invalid, "require_session_binding must be true" unless require_session_binding
    else
      reject_unexpected_disabled_fields!
    end

    unless purpose.nil? || PURPOSES.include?(purpose.to_s)
      raise Invalid, "purpose is invalid"
    end
    if full_reauthentication_required && purpose != "reauthentication"
      raise Invalid, "full reauthentication requires the reauthentication purpose"
    end
    if purpose == "reauthentication" && !full_reauthentication_required
      raise Invalid, "reauthentication requires full_reauthentication_required"
    end
    if phishing_resistant_required && allowed_methods.exclude?(:passkey)
      raise Invalid, "phishing resistance requires an allowed passkey method"
    end
    return unless user_verification_required && allowed_methods.exclude?(:passkey)

    raise Invalid, "user verification requires an allowed passkey method"

  end

  def reject_unexpected_disabled_fields!
    return if purpose.blank? && scope.blank? && allowed_methods.empty? && ttl.nil? &&
      session_binding.blank? && token_binding.blank? && audience.blank? && actor_ref.blank? &&
      resource_ref.nil? && tenant_ref.nil? && !require_session_binding

    raise Invalid, "step_up_required false cannot carry step-up properties"
  end

  def strict_boolean(value, name)
    return value if value == true || value == false

    raise Invalid, "#{name} must be explicitly boolean"
  end

  def normalize_methods(value)
    return [] if value.nil?
    raise Invalid, "allowed_methods must be provided" if value.equal?(UNSET)

    methods = Array(value).map { |method| normalize_method(method) }
    raise Invalid, "allowed_methods contains an invalid method" if methods.any?(&:nil?)
    raise Invalid, "allowed_methods contains an unsupported method" unless (methods - METHODS).empty?

    methods.uniq.freeze
  end

  def normalize_method(value)
    normalized = value.to_s.presence&.downcase&.to_sym
    normalized if normalized && METHODS.include?(normalized)
  end

  def normalize_string(value, name)
    return nil if value.nil?
    raise Invalid, "#{name} must be provided" if value.equal?(UNSET)
    raise Invalid, "#{name} must be a string" unless value.is_a?(String) || value.is_a?(Symbol)

    normalized = value.to_s
    raise Invalid, "#{name} must not be blank" if normalized.blank?
    raise Invalid, "#{name} contains a control character" if normalized.match?(/[\x00-\x1F\x7F]/)

    normalized
  end

  def normalize_ttl(value)
    return nil if value.nil?
    raise Invalid, "ttl must be provided" if value.equal?(UNSET)
    raise Invalid, "ttl must be finite and positive" unless value.is_a?(Numeric) && value.finite? && value.positive?

    value
  end

  def normalize_legacy_aal(value)
    return nil if value.equal?(UNSET) || value.nil? || value == NO_AAL

    raise Invalid, "legacy AAL requirements are unsupported"
  end

  def require_present!(value, name, allow_nil: false)
    return if allow_nil && value.nil?
    return if value.present?

    raise Invalid, "#{name} is required"
  end
end
