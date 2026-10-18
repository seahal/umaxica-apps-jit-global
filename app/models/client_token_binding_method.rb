# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_token_binding_methods
# Database name: op_base_app
#
#  id :bigint           not null, primary key
#
class ClientTokenBindingMethod < OpBaseAppRecord
  include ReferenceRecord

  NOTHING = 0
  DBSC = 1
  LEGACY = 2
  DEFAULTS = [NOTHING, DBSC, LEGACY].freeze

  has_many :client_tokens,
           foreign_key: :user_token_binding_method_id,
           dependent: :restrict_with_error,
           inverse_of: :user_token_binding_method

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
