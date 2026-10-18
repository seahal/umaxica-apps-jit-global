# typed: false
# frozen_string_literal: true

class OrgOperatorLifecycleRequestCreate
  def self.call(actor:, attributes:)
    new(actor: actor, attributes: attributes).call
  end

  def initialize(actor:, attributes:)
    @actor = actor
    @attributes = attributes
  end

  def call
    unless org_owner_authorized?
      request = OperatorLifecycleRequest.new(request_attributes)
      request.errors.add(:organization_id, :not_authorized)
      return OrgOperatorLifecycleResult.new(
        success: false, request: request, error: request.errors.full_messages.to_sentence,
        invitation: nil,
      )
    end

    request = OperatorLifecycleRequest.new(request_attributes)

    if request.save
      OrgOperatorLifecycleResult.new(success: true, request: request, error: nil, invitation: nil)
    else
      OrgOperatorLifecycleResult.new(
        success: false, request: request, error: request.errors.full_messages.to_sentence,
        invitation: nil,
      )
    end
  end

  private

  attr_reader :actor, :attributes

  def request_attributes
    action = attributes[:action].to_s
    {
      action: action,
      target_operator: target_operator_for(action),
      target_email: normalized_target_email,
      organization_id: attributes[:organization_id].presence,
      role_id: attributes[:role_id].presence || 0,
      reason: attributes[:reason].to_s,
      requested_by_operator: actor,
    }
  end

  def target_operator_for(action)
    return nil if action == OperatorLifecycleRequest::ACTION_JOIN

    public_id = attributes[:target_operator_public_id].to_s
    return actor if public_id.blank? && action == OperatorLifecycleRequest::ACTION_WITHDRAW

    Operator.find_by(public_id: Operator.normalize_public_id(public_id))
  end

  def normalized_target_email
    attributes[:target_email].to_s.downcase.strip.presence
  end

  # Only the organization owner may initiate a JOIN lifecycle request for that org.
  # Non-JOIN actions carry no organization_id and are not org-scoped (the 4-eyes approval
  # is the only control for those actions).
  def org_owner_authorized?
    return true unless attributes[:action].to_s == OperatorLifecycleRequest::ACTION_JOIN

    org_id = attributes[:organization_id].to_i
    return false if org_id.zero?

    OperatorOrganization.find_by(id: org_id)&.operator_id == actor.id
  end
end
