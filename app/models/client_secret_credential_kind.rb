# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_secret_credential_kinds
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientSecretCredentialKind < AppPrincipalRecord
  include ReferenceRecord

  LOGIN = 1
  TOTP = 2
  RECOVERY = 3
  API = 4
  DEFAULTS = [LOGIN, TOTP, RECOVERY, API].freeze
  ONE_TIME = RECOVERY
  ALL = [LOGIN, TOTP, RECOVERY, API].freeze

  validates :id, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :id, uniqueness: true

  has_many :client_secret_credentials, inverse_of: :user_secret_credential_kind, dependent: :restrict_with_exception
end
