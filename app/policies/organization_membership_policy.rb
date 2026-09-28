# typed: false
# frozen_string_literal: true

class OrganizationMembershipPolicy < ApplicationPolicy
  public

  def index? = manage_memberships?

  def show? = manage_memberships?

  def new? = change_memberships?

  def create? = change_memberships?

  def edit? = change_memberships?

  def update? = change_memberships?

  def destroy? = change_memberships?

  # Holding a membership lets an Operator read their Bureau's roster; it never lets them change it.
  # Who may change org memberships is not yet decided, so org records deny every change rule
  # (adr/operator-capability-authorization.md, Not provided).
  def change_memberships?
    return false if record.is_a?(AgentMembership) || record.is_a?(Bureau)

    manage_memberships?
  end

  def manage_memberships?
    return false if user.blank?

    case record
    when PersonaMembership
      user.is_a?(Client) && membership_belongs_to_current_principal?(ClientPersona, ClientIdentity, :persona_id)
    when IndividualMembership
      user.is_a?(Visitor) && membership_belongs_to_current_principal?(Individual, VisitorIdentity, :individual_id)
    when AgentMembership
      user.is_a?(Operator) && membership_belongs_to_current_principal?(Agent, OperatorIdentity, :agent_id)
    when Enterprise
      user.is_a?(Client) && collective_belongs_to_current_principal?(
        ClientPersona,
        ClientIdentity,
        PersonaMembership,
        :enterprise_id,
      )
    when Company
      user.is_a?(Visitor) && collective_belongs_to_current_principal?(
        Individual,
        VisitorIdentity,
        IndividualMembership,
        :company_id,
      )
    when Bureau
      user.is_a?(Operator) && collective_belongs_to_current_principal?(
        Agent,
        OperatorIdentity,
        AgentMembership,
        :bureau_id,
      )
    else
      false
    end
  end

  private

  def membership_belongs_to_current_principal?(account_class, identity_class, account_key)
    return false unless record.respond_to?(account_key)

    account_class.joins(account_identity_association(account_class)).exists?(
      :id => record.public_send(account_key),
      identity_class.table_name => { source_record_id: user.id },
    )
  end

  def collective_belongs_to_current_principal?(account_class, identity_class, membership_class, collective_key)
    membership_class.active
      .joins(membership_account_association(membership_class) => account_identity_association(account_class))
      .exists?(
        membership_class.table_name => { collective_key => record.id },
        identity_class.table_name => { source_record_id: user.id },
      )
  end

  def account_identity_association(account_class)
    case account_class.name
    when "ClientPersona" then :client_identity
    when "Individual" then :visitor_identity
    when "Agent" then :operator_identity
    else raise ArgumentError, "unsupported account class: #{account_class.name}"
    end
  end

  def membership_account_association(membership_class)
    case membership_class.name
    when "PersonaMembership" then :persona
    when "IndividualMembership" then :individual
    when "AgentMembership" then :agent
    else raise ArgumentError, "unsupported membership class: #{membership_class.name}"
    end
  end
end
