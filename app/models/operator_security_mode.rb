# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_security_modes
# Database name: org_principal
#
#  id :bigint           not null, primary key
#
# adr/authentication-security-mode.md A2: the only modes are NORMAL and ADVANCED. Rows are created by
# migration 20261023140001.
class OperatorSecurityMode < OrgPrincipalRecord
  NORMAL = 3
  ADVANCED = 7

  DEFAULTS = [NORMAL, ADVANCED].freeze

  has_many :staffs, class_name: "Operator",
                    foreign_key: :security_mode_id,
                    dependent: :restrict_with_error,
                    inverse_of: :security_mode
end
