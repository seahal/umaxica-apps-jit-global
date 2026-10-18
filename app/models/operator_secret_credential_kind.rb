# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_secret_credential_kinds
# Database name: org_principal
#
#  id :bigint           not null, primary key
#

class OperatorSecretCredentialKind < OrgPrincipalRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 1
  LOGIN = 2
  DEFAULTS = [NOTHING, LOGIN].freeze
  ONE_TIME = NOTHING

  # Kind constants
  ALL = [LOGIN].freeze

  has_many :staff_secret_credentials, class_name: "OperatorSecretCredential", inverse_of: :staff_secret_credential_kind,
                                      dependent: :restrict_with_exception

  validates :id, uniqueness: true
end
