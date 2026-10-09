# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_withdrawal_flow_events
# Database name: com_principal
#
#  id                         :bigint           not null, primary key
#  metadata                   :jsonb            not null
#  occurred_at                :datetime         not null
#  reason                     :string(64)       default(""), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  from_status_id             :bigint
#  to_status_id               :bigint           not null
#  token_public_id            :string(64)       default(""), not null
#  visitor_id                 :bigint           not null
#  visitor_withdrawal_flow_id :bigint           not null
#
# Indexes
#
#  idx_on_visitor_withdrawal_flow_id_dada4f9f5b            (visitor_withdrawal_flow_id)
#  index_visitor_withdrawal_flow_events_on_from_status_id  (from_status_id)
#  index_visitor_withdrawal_flow_events_on_occurred_at     (occurred_at)
#  index_visitor_withdrawal_flow_events_on_to_status_id    (to_status_id)
#  index_visitor_withdrawal_flow_events_on_visitor_id      (visitor_id)
#
# Foreign Keys
#
#  fk_rails_...  (from_status_id => visitor_withdrawal_flow_statuses.id) ON DELETE => restrict
#  fk_rails_...  (to_status_id => visitor_withdrawal_flow_statuses.id) ON DELETE => restrict
#  fk_rails_...  (visitor_id => visitors.id) ON DELETE => cascade
#  fk_rails_...  (visitor_withdrawal_flow_id => visitor_withdrawal_flows.id)
#
class VisitorWithdrawalFlowEvent < ComPrincipalRecord
  belongs_to :visitor_withdrawal_flow,
             inverse_of: :visitor_withdrawal_flow_events
  belongs_to :visitor
  belongs_to :from_status,
             class_name: "VisitorWithdrawalFlowStatus"
  belongs_to :to_status,
             class_name: "VisitorWithdrawalFlowStatus"

  validates :from_status_id, inclusion: { in: VisitorWithdrawalFlowStatus::DEFAULTS }, allow_nil: true
  validates :to_status_id, inclusion: { in: VisitorWithdrawalFlowStatus::DEFAULTS }
  validates :occurred_at, presence: true
  validates :token_public_id, length: { maximum: 64 }, allow_blank: true
  validates :reason, length: { maximum: 64 }, allow_blank: true

  before_validation :ensure_withdrawal_flow_status_defaults

  private

  def ensure_withdrawal_flow_status_defaults
    VisitorWithdrawalFlowStatus.ensure_defaults!
  end
end
