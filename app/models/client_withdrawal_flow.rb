# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_withdrawal_flows
# Database name: app_principal
#
#  id           :bigint           not null, primary key
#  began_at     :datetime         not null
#  completed_at :datetime
#  discard_at :datetime         default(Infinity), not null
#  failed_at    :datetime
#  purge_eligible_at    :datetime         default(Infinity), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  client_id    :bigint           not null
#  public_id    :string(21)       not null
#  status_id    :bigint           default(10), not null
#
# Indexes
#
#  index_client_withdrawal_flows_on_began_at      (began_at)
#  index_client_withdrawal_flows_on_client_id     (client_id)
#  index_client_withdrawal_flows_on_completed_at  (completed_at)
#  index_client_withdrawal_flows_on_discard_at  (discard_at)
#  index_client_withdrawal_flows_on_public_id     (public_id) UNIQUE
#  index_client_withdrawal_flows_on_purge_eligible_at     (purge_eligible_at)
#  index_client_withdrawal_flows_on_status_id     (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => clients.id)
#  fk_rails_...  (status_id => client_withdrawal_flow_statuses.id)
#
class ClientWithdrawalFlow < AppPrincipalRecord
  include WithdrawalFlow
  include FlowWithdrawal

  STATUS_MODEL = ClientWithdrawalFlowStatus
  EVENT_MODEL = ClientWithdrawalFlowEvent
  ACTOR_FOREIGN_KEY = :client_id
  WITHDRAWAL_CYCLE_FOREIGN_KEY = :client_withdrawal_flow_id
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

  belongs_to :client,
             class_name: "Client",
             inverse_of: :client_withdrawal_flows
  belongs_to :status,
             class_name: "ClientWithdrawalFlowStatus"
  has_many :client_withdrawal_flow_events,
           dependent: :delete_all,
           inverse_of: :client_withdrawal_flow
end
