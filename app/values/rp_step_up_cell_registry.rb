# frozen_string_literal: true

# Fixed Base RP cell ownership for the OP-mediated step-up flow.
class RpStepUpCellRegistry
  Entry = Data.define(
    :cell, :record_class, :session_class, :binding_class, :identity_binding_class, :principal_class, :actor_class,
    :state_class, :status_class, :transition_class, :audit_source_key, :resource_type, :callback_path,
  )

  ENTRIES = {
    "rp_base_app" => Entry.new(
      cell: RpCellBinding.fetch("rp_base_app"), record_class: RpBaseAppRecord, session_class: RpBaseAppSession,
      binding_class: RpBaseAppOpSessionBinding, identity_binding_class: RpBaseAppIdentityBinding,
      principal_class: RpBaseAppPrincipal, actor_class: Client, state_class: RpStepUpState,
      status_class: RpStepUpStateStatus, transition_class: RpStepUpStateTransition,
      audit_source_key: "rp_base_app", resource_type: "client",
      callback_path: AuthBoundaryAuthorityMap.step_up_callback_path_for("base-app-ww"),
    ),
    "rp_base_org" => Entry.new(
      cell: RpCellBinding.fetch("rp_base_org"), record_class: RpBaseOrgRecord, session_class: RpBaseOrgSession,
      binding_class: RpBaseOrgOpSessionBinding, identity_binding_class: RpBaseOrgIdentityBinding,
      principal_class: RpBaseOrgPrincipal, actor_class: Operator, state_class: RpBaseOrgStepUpState,
      status_class: RpBaseOrgStepUpStateStatus, transition_class: RpBaseOrgStepUpStateTransition,
      audit_source_key: "rp_base_org", resource_type: "operator",
      callback_path: AuthBoundaryAuthorityMap.step_up_callback_path_for("base-org-ww"),
    ),
  }.freeze

  class << self
    public

    def fetch(cell)
      raise ArgumentError, "step-up requires a registered RP cell" unless cell.is_a?(RpCellBinding::Cell)

      entry =
        ENTRIES.fetch(cell.connection) do
          raise ArgumentError, "step-up is supported only by Base RP cells"
        end
      raise ArgumentError, "step-up cell binding is inconsistent" unless entry.cell == cell

      entry
    end
  end
end
