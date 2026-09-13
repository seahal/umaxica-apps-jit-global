# typed: false
# frozen_string_literal: true

# Base policy class for authorization using Action Policy
class ApplicationPolicy < ActionPolicy::Base
  # Actor::Context is the primary authorization context. Legacy policies may
  # still consume `user`, which is derived from the actor context when omitted.
  authorize :actor, optional: true
  authorize :user, optional: true

  alias_rule :edit?, to: :update?
  alias_rule :new?, to: :create?

  # Session capability layer. Authorization is DB role AND session capability
  # AND the ordinary policy rule; an authentication context can only ever
  # narrow what the actor's roles already allow, never widen it.
  #
  # The check is a pre-check rather than a condition inside each rule so that a
  # newly added sensitive action is covered without anyone remembering to guard
  # it (docs/security/org-emergency-access.md).
  pre_check :deny_capability_restricted_context

  def edit? = update?

  def new? = create?

  def user
    @user || actor_resource
  end

  # Default permissions - deny all by default (allowlist approach)
  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def update?
    false
  end

  def destroy?
    false
  end

  relation_scope do |relation|
    relation.none
  end

  # Named by the pre_check above; Action Policy resolves it on the policy
  # instance, so it is not part of the policy's public rule vocabulary.
  def deny_capability_restricted_context
    rule = result&.rule
    return if rule.blank?

    deny! unless authentication_context.permits_rule?(rule)
  end

  # The trusted authentication context of the current session, read from the
  # signed access token. An absent claim is a session minted before Emergency
  # Access existed and is Normal; an unrecognised value carries no capabilities
  # at all, so a tampered or unknown context denies rather than defaulting open.
  def authentication_context
    AuthorizationTokenClaims.authentication_context(current_token)
  end

  def emergency_session?
    authentication_context.emergency?
  end

  protected

  def actor_context
    return actor if defined?(Actor::Context) && actor.is_a?(Actor::Context)

    nil
  end

  def actor_resource
    resource = actor_context&.actor
    return nil if resource.respond_to?(:unauthenticated?) && resource.unauthenticated?

    resource
  end

  # Get the organization from the record if it has one
  # @return [Object, nil]
  def organization
    @organization ||=
      if record.respond_to?(:organization)
        record.organization
      elsif record.respond_to?(:organization_id)
        record.organization_id
      end
  end

  # Extract JWT scopes from the current user token.
  # @return [Array<String>]
  def jwt_scopes
    return [] if current_token.blank?

    AuthorizationTokenClaims.scopes(current_token)
  end

  # Check if the user has a specific scope
  # @param scope [String] the scope to check (e.g., "read:self", "write:org")
  # @return [Boolean]
  def has_scope?(scope)
    jwt_scopes.include?(scope.to_s)
  end

  # Check if the user has permission for the current domain
  # @param allowed_domains [Array<String>] list of allowed domain prefixes (e.g., ["app", "org"])
  # @return [Boolean]
  def domain_permitted?(*allowed_domains)
    return true if allowed_domains.blank?

    domain = extract_domain_from_audience
    return true if domain.blank?

    allowed_domains.map(&:to_s).include?(domain.to_s)
  end

  # Extract domain from audience claim in the current user token.
  def extract_domain_from_audience
    return nil if current_token.blank?

    audiences = Array(current_token["aud"])
    return nil if audiences.empty?

    audiences.first.to_s.split(".").first
  end

  # Get JWT subject (user ID) from the current user token.
  def jwt_subject
    return nil if current_token.blank?

    AuthorizationTokenClaims.subject(current_token)
  end

  # Check if current token is for specific domain
  def domain_app?
    extract_domain_from_audience == "app"
  end

  def domain_org?
    extract_domain_from_audience == "org"
  end

  def domain_com?
    extract_domain_from_audience == "com"
  end

  # Check if user owns the record
  # @return [Boolean]
  def owner?
    return false unless user
    return jwt_subject.to_s == user.id.to_s if record.blank?
    return true if same_user_record?

    if user.is_a?(Client) && record.respond_to?(:user_id)
      record.user_id == user.id
    elsif user.is_a?(Operator) && record.respond_to?(:staff_id)
      record.staff_id == user.id
    elsif defined?(Visitor) && user.is_a?(Visitor) && record.respond_to?(:visitor_id)
      record.visitor_id == user.id
    else
      false
    end
  end

  def same_user_record?
    return false unless record.respond_to?(:id)

    same_user_record_type? && record.id == user.id
  end

  def same_user_record_type?
    (user.is_a?(Client) && record.is_a?(Client)) ||
      (user.is_a?(Operator) && record.is_a?(Operator)) ||
      (defined?(Visitor) && user.is_a?(Visitor) && record.is_a?(Visitor))
  end

  # Role-based checks
  def operator?
    user&.has_role?("operator", organization: organization)
  end

  def manager?
    user&.has_role?("manager", organization: organization)
  end

  def editor?
    user&.has_role?("editor", organization: organization)
  end

  def contributor?
    user&.has_role?("contributor", organization: organization)
  end

  def viewer?
    user&.has_role?("viewer", organization: organization)
  end

  # Combined role checks
  def operator_or_manager?
    user&.operator_or_manager?(organization: organization)
  end

  def can_edit?
    user&.can_edit?(organization: organization)
  end

  def can_view?
    user&.can_view?(organization: organization)
  end

  def can_contribute?
    user&.can_contribute?(organization: organization)
  end

  def current_token
    Actor.authz.token_claims
  end
end
