# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: core_org_operator_bridges
# Database name: org_zenith
#
#  id           :bigint           not null, primary key
#  audience     :string           default("umaxica-core-org"), not null
#  host         :string           default("jpx.umaxica.org"), not null
#  lock_version :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  operator_id  :bigint           not null
#  public_id    :string           default(""), not null
#  rp_client_id :string           default("core_org"), not null
#
# Indexes
#
#  idx_core_org_operator_bridges_unique_operator_rp  (operator_id,rp_client_id) UNIQUE
#  index_core_org_operator_bridges_on_public_id      (public_id) UNIQUE
#
class CoreOrgOperatorBridge < OrgRpRecord
  include CoreRpBridge

  belongs_to :operator,
             class_name: "Operator",
             inverse_of: :core_org_operator_bridge

  core_rp_bridge(
    actor_association_name: :operator,
    actor_foreign_key: :operator_id,
    client_id: "core-org",
    audience: "umaxica-core-org",
    host: "jpx.umaxica.org",
  )
end
