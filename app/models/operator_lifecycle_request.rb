# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_lifecycle_requests
# Database name: org_principal
#
#  id                       :bigint           not null, primary key
#  action                   :string           not null
#  approved_at              :datetime
#  executed_at              :datetime
#  lock_version             :integer          default(0), not null
#  reason                   :text
#  rejected_at              :datetime
#  rejection_reason         :text
#  status                   :string           default("pending"), not null
#  target_email             :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  approved_by_operator_id  :bigint
#  executed_by_operator_id  :bigint
#  invitation_id            :bigint
#  organization_id          :bigint
#  public_id                :string(21)       not null
#  rejected_by_operator_id  :bigint
#  requested_by_operator_id :bigint           not null
#  role_id                  :bigint           default(0), not null
#  target_operator_id       :bigint
#
# Indexes
#
#  index_operator_lifecycle_requests_on_action                    (action)
#  index_operator_lifecycle_requests_on_approved_by_operator_id   (approved_by_operator_id)
#  index_operator_lifecycle_requests_on_executed_by_operator_id   (executed_by_operator_id)
#  index_operator_lifecycle_requests_on_public_id                 (public_id) UNIQUE
#  index_operator_lifecycle_requests_on_rejected_by_operator_id   (rejected_by_operator_id)
#  index_operator_lifecycle_requests_on_requested_by_operator_id  (requested_by_operator_id)
#  index_operator_lifecycle_requests_on_status                    (status)
#  index_operator_lifecycle_requests_on_target_email              (target_email)
#  index_operator_lifecycle_requests_on_target_operator_id        (target_operator_id)
#
# Foreign Keys
#
#  fk_rails_...  (requested_by_operator_id => operators.id) ON DELETE => restrict
#
class OperatorLifecycleRequest < OrgPrincipalRecord
  self.belongs_to_required_by_default = false

  include PublicId

  ACTION_JOIN = "join"
  ACTION_WITHDRAW = "withdraw"
  ACTION_SUSPEND = "suspend"
  ACTION_TERMINATE = "terminate"
  ACTION_RESTORE = "restore"
  ACTIONS = [ACTION_JOIN, ACTION_WITHDRAW, ACTION_SUSPEND, ACTION_TERMINATE, ACTION_RESTORE].freeze

  STATUS_PENDING = "pending"
  STATUS_APPROVED = "approved"
  STATUS_REJECTED = "rejected"
  STATUS_EXECUTED = "executed"
  STATUS_CANCELLED = "cancelled"
  STATUSES = [STATUS_PENDING, STATUS_APPROVED, STATUS_REJECTED, STATUS_EXECUTED, STATUS_CANCELLED].freeze

  attr_accessor :target_operator_public_id

  belongs_to :target_operator,
             class_name: "Operator"
  belongs_to :requested_by_operator,
             class_name: "Operator"
  belongs_to :approved_by_operator,
             class_name: "Operator"
  belongs_to :rejected_by_operator,
             class_name: "Operator"
  belongs_to :executed_by_operator,
             class_name: "Operator"

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :status, inclusion: { in: STATUSES }
  validates :target_email, presence: true, if: :join?
  validates :organization_id, presence: true, if: :join?
  validates :target_operator, presence: true, unless: :join?
  validates :reason, length: { maximum: 2000 }, allow_blank: true
  validates :rejection_reason, length: { maximum: 2000 }, allow_blank: true
  validates :requested_by_operator_id, exclusion: { in: [nil] }

  scope :pending, -> { where(status: STATUS_PENDING) }
  scope :approved, -> { where(status: STATUS_APPROVED) }

  def join? = action == ACTION_JOIN

  def withdraw? = action == ACTION_WITHDRAW

  def suspend? = action == ACTION_SUSPEND

  def terminate? = action == ACTION_TERMINATE

  def restore? = action == ACTION_RESTORE

  def pending? = status == STATUS_PENDING

  def approved? = status == STATUS_APPROVED

  def rejected? = status == STATUS_REJECTED

  def executed? = status == STATUS_EXECUTED

  def closed?
    rejected? || executed? || status == STATUS_CANCELLED
  end

  def to_param
    public_id
  end
end
