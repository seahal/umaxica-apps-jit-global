# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_preference_adult_content_gate_options
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
class OperatorPreferenceAdultContentGateOption < OrgPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  APPROVED = 1
  DENY = 2
  DEFAULTS = [NOTHING, APPROVED, DENY].freeze

  has_many :operator_preference_adult_content_gates,
           foreign_key: :option_id,
           inverse_of: :option,
           dependent: :restrict_with_error

  def self.ensure_defaults! = insert_missing_fixed_ids!(DEFAULTS)

  def name
    case id
    when NOTHING then "nothing"
    when APPROVED then "approved"
    when DENY then "deny"
    end
  end

  def approved? = id == APPROVED

  def denied? = id == DENY

  def enabled? = denied?
end
