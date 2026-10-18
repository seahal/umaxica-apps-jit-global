# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_withdrawal_flow_events
# Database name: app_principal
#
#  id                        :bigint           not null, primary key
#  metadata                  :jsonb            not null
#  occurred_at               :datetime         not null
#  reason                    :string(64)       default(""), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  client_id                 :bigint           not null
#  client_withdrawal_flow_id :bigint           not null
#  from_status_id            :bigint
#  to_status_id              :bigint           not null
#  token_public_id           :string(64)       default(""), not null
#
# Indexes
#
#  idx_on_client_withdrawal_flow_id_128dba0f0d            (client_withdrawal_flow_id)
#  index_client_withdrawal_flow_events_on_client_id       (client_id)
#  index_client_withdrawal_flow_events_on_from_status_id  (from_status_id)
#  index_client_withdrawal_flow_events_on_occurred_at     (occurred_at)
#  index_client_withdrawal_flow_events_on_to_status_id    (to_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => clients.id) ON DELETE => cascade
#  fk_rails_...  (client_withdrawal_flow_id => client_withdrawal_flows.id)
#  fk_rails_...  (from_status_id => client_withdrawal_flow_statuses.id) ON DELETE => restrict
#  fk_rails_...  (to_status_id => client_withdrawal_flow_statuses.id) ON DELETE => restrict
#
class ClientWithdrawalFlowEvent < AppPrincipalRecord
  belongs_to :client_withdrawal_flow,
             inverse_of: :client_withdrawal_flow_events
  belongs_to :client,
             class_name: "Client"
  belongs_to :from_status,
             class_name: "ClientWithdrawalFlowStatus"
  belongs_to :to_status,
             class_name: "ClientWithdrawalFlowStatus"

  validates :from_status_id, inclusion: { in: ClientWithdrawalFlowStatus::DEFAULTS }, allow_nil: true
  validates :to_status_id, inclusion: { in: ClientWithdrawalFlowStatus::DEFAULTS }
  validates :occurred_at, presence: true
  validates :token_public_id, length: { maximum: 64 }, allow_blank: true
  validates :reason, length: { maximum: 64 }, allow_blank: true

  before_validation :ensure_withdrawal_flow_status_defaults

  private

  def ensure_withdrawal_flow_status_defaults
    ClientWithdrawalFlowStatus.ensure_defaults!
  end
end
