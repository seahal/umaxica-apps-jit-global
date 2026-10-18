# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_token_binding_methods
# Database name: op_base_org
#
#  id :bigint           not null, primary key
#
class OperatorTokenBindingMethod < OpBaseOrgRecord
  include ReferenceRecord

  NOTHING = 0
  DBSC = 1
  LEGACY = 2
  DEFAULTS = [NOTHING, DBSC, LEGACY].freeze

  has_many :staff_tokens,
           class_name: "OperatorToken",
           foreign_key: :staff_token_binding_method_id,
           dependent: :restrict_with_error,
           inverse_of: :staff_token_binding_method
  has_many :operator_tokens,
           class_name: "OperatorToken",
           foreign_key: :staff_token_binding_method_id,
           dependent: :restrict_with_error,
           inverse_of: :staff_token_binding_method

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
