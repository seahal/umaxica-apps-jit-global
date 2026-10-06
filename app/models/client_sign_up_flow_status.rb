# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_sign_up_flow_statuses
# Database name: app_ticket
#
#  id :bigint           not null, primary key
#
class ClientSignUpFlowStatus < AppTicketRecord
  include ReferenceRecord

  STARTED = 10
  CONTACT_PENDING = 20
  CREDENTIAL_PENDING = 30
  CONTACT_VERIFIED = 35
  SOCIAL_CALLBACK_PENDING = 36
  GUARDRAIL_PENDING = 38
  CHECKPOINT_PENDING = 40
  FINALIZING = 60
  FINALIZED = 70
  SIGN_IN_HANDOFF_PENDING = 80
  COMPLETED = 100
  FAILED = 900
  EXPIRED = 910
  CANCELLED = 920
  HALTED = 930
  DEFAULTS = [
    STARTED,
    CONTACT_PENDING,
    CREDENTIAL_PENDING,
    CONTACT_VERIFIED,
    SOCIAL_CALLBACK_PENDING,
    GUARDRAIL_PENDING,
    CHECKPOINT_PENDING,
    FINALIZING,
    FINALIZED,
    SIGN_IN_HANDOFF_PENDING,
    COMPLETED,
    FAILED,
    EXPIRED,
    CANCELLED,
    HALTED,
  ].freeze

  has_many :client_sign_up_flows,
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :status
end
