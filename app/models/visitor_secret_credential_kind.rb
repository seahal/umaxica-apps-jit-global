# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_secret_credential_kinds
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
class VisitorSecretCredentialKind < ComPrincipalRecord
  include ReferenceRecord

  LOGIN = 1
  RECOVERY = 3
  API = 4
  DEFAULTS = [LOGIN, RECOVERY, API].freeze
  ONE_TIME = RECOVERY
  ALL = [LOGIN, RECOVERY, API].freeze

  validates :id, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :id, uniqueness: true

  has_many :visitor_secret_credentials, inverse_of: :visitor_secret_credential_kind, dependent: :restrict_with_exception
end
