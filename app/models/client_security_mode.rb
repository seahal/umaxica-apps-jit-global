# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_security_modes
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
# adr/authentication-security-mode.md A2: the only modes are NORMAL and ADVANCED. Rows are created by
# migration 20261023140001.
class ClientSecurityMode < AppPrincipalRecord
  NORMAL = 3
  ADVANCED = 7

  DEFAULTS = [NORMAL, ADVANCED].freeze

  has_many :users, class_name: "Client",
                   foreign_key: :security_mode_id,
                   dependent: :restrict_with_error,
                   inverse_of: :security_mode
end
