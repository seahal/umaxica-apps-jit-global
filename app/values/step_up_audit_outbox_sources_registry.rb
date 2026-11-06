# frozen_string_literal: true

class StepUpAuditOutboxSourcesRegistry
  SOURCES = {
    "o9_app" => [ClientSensitiveAdmissionAuditOutbox, "APP", ClientSensitiveAdmissionAuditAttempt,
                 ClientStepUpAuditOutboxDeliveryState::PENDING, ClientStepUpAuditOutboxDeliveryState::DELIVERED,].freeze,
    "o9_org" => [OperatorSensitiveAdmissionAuditOutbox, "ORG", OperatorSensitiveAdmissionAuditAttempt,
                 OperatorStepUpAuditOutboxDeliveryState::PENDING, OperatorStepUpAuditOutboxDeliveryState::DELIVERED,].freeze,
    "op_app" => [
      ClientStepUpAuditOutbox,
      "APP",
      ClientStepUpAuditOutboxAttempt,
      ClientStepUpAuditOutboxDeliveryState::PENDING,
      ClientStepUpAuditOutboxDeliveryState::DELIVERED,
    ].freeze,
    "op_org" => [
      OperatorStepUpAuditOutbox,
      "ORG",
      OperatorStepUpAuditOutboxAttempt,
      OperatorStepUpAuditOutboxDeliveryState::PENDING,
      OperatorStepUpAuditOutboxDeliveryState::DELIVERED,
    ].freeze,
    "rp_base_app" => [
      RpStepUpAuditOutbox,
      "APP",
      RpStepUpAuditOutboxAttempt,
      RpStepUpAuditOutboxDeliveryState::PENDING,
      RpStepUpAuditOutboxDeliveryState::DELIVERED,
    ].freeze,
    "rp_base_org" => [
      RpBaseOrgStepUpAuditOutbox,
      "ORG",
      RpBaseOrgStepUpAuditOutboxAttempt,
      RpBaseOrgStepUpAuditOutboxDeliveryState::PENDING,
      RpBaseOrgStepUpAuditOutboxDeliveryState::DELIVERED,
    ].freeze,
  }.freeze
end
