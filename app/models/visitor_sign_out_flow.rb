# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_sign_out_flows
# Database name: com_ticket
#
#  id                      :bigint           not null, primary key
#  access_discarded_at     :datetime
#  access_expires_at       :datetime         not null
#  completed_at            :datetime
#  discard_at            :datetime         default(Infinity), not null
#  failed_at               :datetime
#  logically_revoked_at    :datetime
#  nonce_digest            :string
#  purge_eligible_at               :datetime         default(Infinity), not null
#  refresh_expires_at      :datetime         not null
#  requested_at            :datetime         not null
#  return_to               :text
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  kind_id                 :bigint           default(0), not null
#  principal_id            :bigint
#  public_id               :string(21)       not null
#  refresh_token_family_id :string
#  status_id               :bigint           default(10), not null
#  token_id                :bigint
#
# Indexes
#
#  index_visitor_sign_out_flows_on_access_expires_at        (access_expires_at)
#  index_visitor_sign_out_flows_on_discard_at             (discard_at)
#  index_visitor_sign_out_flows_on_kind_id                  (kind_id)
#  index_visitor_sign_out_flows_on_principal_id             (principal_id)
#  index_visitor_sign_out_flows_on_public_id                (public_id) UNIQUE
#  index_visitor_sign_out_flows_on_purge_eligible_at                (purge_eligible_at)
#  index_visitor_sign_out_flows_on_refresh_expires_at       (refresh_expires_at)
#  index_visitor_sign_out_flows_on_refresh_token_family_id  (refresh_token_family_id)
#  index_visitor_sign_out_flows_on_status_id                (status_id)
#  index_visitor_sign_out_flows_on_token_id                 (token_id)
#
# Foreign Keys
#
#  fk_rails_...  (kind_id => visitor_sign_out_flow_kinds.id)
#  fk_rails_...  (status_id => visitor_sign_out_flow_statuses.id)
#  fk_rails_...  (token_id => visitor_tokens.id) ON DELETE => cascade
#
class VisitorSignOutFlow < ComTicketRecord
  include SignOutFlow
  include FlowSignOut

  STATUS_MODEL = VisitorSignOutFlowStatus
  KIND_MODEL = VisitorSignOutFlowKind
  STATUSES = {
    "NOTHING" => STATUS_MODEL::NOTHING,
    "REQUESTED" => STATUS_MODEL::REQUESTED,
    "ACCESS_DISCARDED" => STATUS_MODEL::ACCESS_DISCARDED,
    "LOGICALLY_REVOKED" => STATUS_MODEL::LOGICALLY_REVOKED,
    "AWAITING_EXPIRY" => STATUS_MODEL::AWAITING_EXPIRY,
    "COMPLETED" => STATUS_MODEL::COMPLETED,
    "FAILED" => STATUS_MODEL::FAILED,
    "EXPIRED" => STATUS_MODEL::EXPIRED,
    "CANCELLED" => STATUS_MODEL::CANCELLED,
    "HALTED" => STATUS_MODEL::HALTED,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze
  KINDS = {
    "NOTHING" => KIND_MODEL::NOTHING,
    "IDP_SIGN_OUT" => KIND_MODEL::IDP_SIGN_OUT,
    "RP_INITIATED" => KIND_MODEL::RP_INITIATED,
    "SESSION_REVOKE" => KIND_MODEL::SESSION_REVOKE,
  }.freeze
  KIND_NAMES = KINDS.invert.freeze
  KIND_IDS = KINDS.values.freeze
  TRANSITIONS = {
    STATUS_MODEL::NOTHING => [STATUS_MODEL::REQUESTED],
    STATUS_MODEL::REQUESTED => [STATUS_MODEL::ACCESS_DISCARDED, STATUS_MODEL::EXPIRED, STATUS_MODEL::CANCELLED, STATUS_MODEL::HALTED],
    STATUS_MODEL::ACCESS_DISCARDED => [STATUS_MODEL::LOGICALLY_REVOKED, STATUS_MODEL::EXPIRED, STATUS_MODEL::CANCELLED,
                                       STATUS_MODEL::HALTED,],
    STATUS_MODEL::LOGICALLY_REVOKED => [STATUS_MODEL::COMPLETED, STATUS_MODEL::EXPIRED, STATUS_MODEL::CANCELLED, STATUS_MODEL::HALTED],
    STATUS_MODEL::AWAITING_EXPIRY => [],
    STATUS_MODEL::COMPLETED => [],
    STATUS_MODEL::FAILED => [],
    STATUS_MODEL::EXPIRED => [],
    STATUS_MODEL::CANCELLED => [],
    STATUS_MODEL::HALTED => [],
  }.freeze

  belongs_to :token, class_name: "VisitorToken"
  belongs_to :status, class_name: "VisitorSignOutFlowStatus"
  belongs_to :kind, class_name: "VisitorSignOutFlowKind"
end
