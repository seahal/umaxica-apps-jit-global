# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_withdrawal_flows
# Database name: com_principal
#
#  id           :bigint           not null, primary key
#  began_at     :datetime         not null
#  completed_at :datetime
#  discard_at :datetime         default(Infinity), not null
#  failed_at    :datetime
#  purge_eligible_at    :datetime         default(Infinity), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  public_id    :string(21)       not null
#  status_id    :bigint           default(10), not null
#  visitor_id   :bigint           not null
#
# Indexes
#
#  index_visitor_withdrawal_flows_on_began_at      (began_at)
#  index_visitor_withdrawal_flows_on_completed_at  (completed_at)
#  index_visitor_withdrawal_flows_on_discard_at  (discard_at)
#  index_visitor_withdrawal_flows_on_public_id     (public_id) UNIQUE
#  index_visitor_withdrawal_flows_on_purge_eligible_at     (purge_eligible_at)
#  index_visitor_withdrawal_flows_on_status_id     (status_id)
#  index_visitor_withdrawal_flows_on_visitor_id    (visitor_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => visitor_withdrawal_flow_statuses.id)
#  fk_rails_...  (visitor_id => visitors.id)
#
class VisitorWithdrawalFlow < ComPrincipalRecord
  include WithdrawalFlow
  include FlowWithdrawal

  STATUS_MODEL = VisitorWithdrawalFlowStatus
  EVENT_MODEL = VisitorWithdrawalFlowEvent
  ACTOR_FOREIGN_KEY = :visitor_id
  WITHDRAWAL_CYCLE_FOREIGN_KEY = :visitor_withdrawal_flow_id
  STATUSES = {
    "NOTHING" => STATUS_MODEL::NOTHING,
    "REQUESTED" => STATUS_MODEL::REQUESTED,
    "CLOSING" => STATUS_MODEL::CLOSING,
    "DISCARDED" => STATUS_MODEL::DISCARDED,
    "RECOVERED" => STATUS_MODEL::RECOVERED,
    "TERMINATED" => STATUS_MODEL::TERMINATED,
    "FAILED" => STATUS_MODEL::FAILED,
  }.freeze
  STATUS_NAMES = STATUSES.invert.freeze
  STATUS_IDS = STATUSES.values.freeze
  TRANSITIONS = {
    STATUS_MODEL::NOTHING => [STATUS_MODEL::REQUESTED],
    STATUS_MODEL::REQUESTED => [STATUS_MODEL::CLOSING, STATUS_MODEL::FAILED],
    STATUS_MODEL::CLOSING => [STATUS_MODEL::DISCARDED, STATUS_MODEL::FAILED],
    STATUS_MODEL::DISCARDED => [STATUS_MODEL::RECOVERED, STATUS_MODEL::TERMINATED, STATUS_MODEL::FAILED],
    STATUS_MODEL::RECOVERED => [],
    STATUS_MODEL::TERMINATED => [],
    STATUS_MODEL::FAILED => [],
  }.freeze

  belongs_to :visitor,
             inverse_of: :visitor_withdrawal_flows
  belongs_to :status,
             class_name: "VisitorWithdrawalFlowStatus"
  has_many :visitor_withdrawal_flow_events,
           dependent: :delete_all,
           inverse_of: :visitor_withdrawal_flow
end
