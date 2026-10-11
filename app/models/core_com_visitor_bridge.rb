# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: core_com_visitor_bridges
# Database name: com_zenith
#
#  id           :bigint           not null, primary key
#  audience     :string           default("umaxica-core-com"), not null
#  host         :string           default("jpx.umaxica.com"), not null
#  lock_version :integer          default(0), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  public_id    :string           default(""), not null
#  rp_client_id :string           default("core_com"), not null
#  visitor_id   :bigint           not null
#
# Indexes
#
#  idx_core_com_visitor_bridges_unique_visitor_rp  (visitor_id,rp_client_id) UNIQUE
#  index_core_com_visitor_bridges_on_public_id     (public_id) UNIQUE
#
class CoreComVisitorBridge < ComRpRecord
  include CoreRpBridge

  belongs_to :visitor,
             inverse_of: :core_com_visitor_bridge

  core_rp_bridge(
    actor_association_name: :visitor,
    actor_foreign_key: :visitor_id,
    client_id: "core-com",
    audience: "umaxica-core-com",
    host: "jpx.umaxica.com",
  )
end
