# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_token_binding_methods
# Database name: op_base_com
#
#  id :bigint           not null, primary key
#
class VisitorTokenBindingMethod < OpBaseComRecord
  include ReferenceRecord

  NOTHING = 0
  DBSC = 1
  LEGACY = 2
  DEFAULTS = [NOTHING, DBSC, LEGACY].freeze

  has_many :visitor_tokens, dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
