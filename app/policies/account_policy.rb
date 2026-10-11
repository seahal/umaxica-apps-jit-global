# typed: false
# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  def show?
    account_owned_by_current_principal?
  end

  private

  def account_owned_by_current_principal?
    case record
    when ClientPersona
      user.is_a?(Client) && record.client_identity&.source_record_id == user.id
    when Individual
      user.is_a?(Visitor) && record.visitor_identity&.source_record_id == user.id
    when Agent
      user.is_a?(Operator) && record.operator_identity&.source_record_id == user.id
    else
      false
    end
  end
end
