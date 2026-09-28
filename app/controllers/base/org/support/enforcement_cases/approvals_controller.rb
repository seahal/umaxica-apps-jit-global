# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      module EnforcementCases
        # adr/unified-enforcement.md, Approval: the approving operator must differ from the applying
        # operator -- enforced as a CHECK constraint (chk_*_enforcement_cases_approval_separation)
        # and by EnforcementCasePolicy#approve?. Effects are attached and confirmed at approval
        # time, never carried over unreviewed from the initial `create`.
        #
        # The approver is claimed under the Case row lock before the Case is applied, so two
        # concurrent approvals cannot both apply it: the second sees the recorded approver and is
        # refused as a conflict.
        class ApprovalsController < Base::Org::ApplicationController
          include ::SurfaceInertiaPage
          include ::EnforcementCaseRealmResolvable
          include ::OrgAdministrationPage
          include ::OrgEnforcementCasePage

          AUTHENTICATION_MODE = :private
          STEP_UP_SCOPE = "enforcement_case_approve"

          class ApprovalConflictError < StandardError; end

          declare_authentication_mode! :private
          before_action :authenticate_operator!
          before_action :no_store
          before_action :set_enforcement_case
          before_action :authorize_approval!, only: :new
          before_action :require_enforcement_step_up!, only: :new

          public

          def new
            return render_conflict unless @enforcement_case.state == "pending_approval"

            render inertia: "base/org/support/enforcement_cases/approvals/new", props: confirmation_props
          end

          def create
            authorize!(@enforcement_case, with: EnforcementCasePolicy, to: :approve?)
            return unless require_enforcement_step_up!

            claim_approval!
            begin
              attach_requested_effects!(@enforcement_case)
              EnforcementCaseApplyOperation.call(
                enforcement_case: @enforcement_case, actor_operator_public_id: current_operator.public_id,
              )
            rescue StandardError
              # Any failure: release_unapplied_claim! decides from the committed state whether the
              # claim can be withdrawn, and the original error is re-raised either way.
              release_unapplied_claim!
              raise
            end
            respond_to do |format|
              format.json do
                render json: { public_id: @enforcement_case.public_id, state: @enforcement_case.state }, status: :ok
              end
              format.html { redirect_to(enforcement_case_path_for(@enforcement_case), status: :see_other) }
            end
          rescue ApprovalConflictError
            render_conflict
          rescue ActiveRecord::RecordInvalid, ArgumentError, EnforcementCaseApplicable::ApprovalRequiredError,
                 EnforcementCaseApplicable::InvalidStateTransitionError => e
            respond_to do |format|
              format.json { render json: { error: e.message }, status: :unprocessable_content }
              format.html do
                render inertia: "base/org/support/enforcement_cases/approvals/new",
                       props: confirmation_props(errors: { base: e.message }),
                       status: :unprocessable_content
              end
            end
          end

          private

          def no_store
            response.headers["Cache-Control"] = "private, no-store"
          end

          # True when Step-Up is satisfied; otherwise the Step-Up response has been rendered.
          def require_enforcement_step_up!
            require_step_up!(scope: STEP_UP_SCOPE)
            !performed?
          end

          def set_enforcement_case
            @enforcement_case = enforcement_case_class.includes(
              :principal_effect,
              :appeal,
            ).find_by!(public_id: params.expect(:enforcement_case_id))
          end

          def authorize_approval!
            authorize!(@enforcement_case, with: EnforcementCasePolicy, to: :approve?)
          end

          def claim_approval!
            @enforcement_case.with_lock do
              pending = @enforcement_case.state == "pending_approval"
              raise ApprovalConflictError unless pending && @enforcement_case.approved_by_operator_public_id.nil?

              @enforcement_case.update!(approved_by_operator_public_id: current_operator.public_id)
            end
          end

          # Withdraws the claim only when nothing observable has happened. EnforcementCaseApplyOperation
          # commits the state change and the effect rows in one transaction and performs the account
          # lock, session revocation, and audit only after that commit, so a Case still in
          # pending_approval under its row lock has had no side effect. Any other state (active, or
          # failed after the apply started) keeps its approver and is left for reconciliation; an
          # applied lock is never undone to make the Case look pending again.
          def release_unapplied_claim!
            @enforcement_case.reload.with_lock do
              next unless @enforcement_case.state == "pending_approval" &&
                @enforcement_case.approved_by_operator_public_id == current_operator.public_id

              @enforcement_case.update!(approved_by_operator_public_id: nil)
            end
          end

          def render_conflict
            message = t("base.org.admin.errors.conflict")
            respond_to do |format|
              format.json { render json: { error: message }, status: :conflict }
              format.html do
                render inertia: "base/org/support/enforcement_cases/approvals/new",
                       props: confirmation_props(errors: { base: message }),
                       status: :conflict
              end
            end
          end

          # The effects always target the Case's own principal.
          def attach_requested_effects!(enforcement_case)
            if (attrs = params[:principal_effect]).present?
              enforcement_case.build_principal_effect(
                attrs.permit(
                  :access_blocking,
                  :recovery_blocked,
                  :reactivation_blocked,
                  :withdrawal_purge_blocked,
                  :principal_hard_delete_blocked,
                  :profile_effect,
                ).to_h.merge(principal_public_id: enforcement_case.principal_public_id, effective_at: Time.current),
              )
            end
            return if (attrs = params[:authentication_method_effect]).blank?

            enforcement_case.authentication_method_effects.build(
              attrs.permit(:authentication_method, :effect).to_h.merge(
                principal_public_id: enforcement_case.principal_public_id, effective_at: Time.current,
              ),
            )
          end

          def confirmation_props(errors: {})
            enforcement_confirmation_props(
              @enforcement_case,
              title: t("base.org.admin.enforcement.approve_title"),
              effect: t("base.org.admin.enforcement.approve_effect"),
              action: request.path.delete_suffix("/new"),
              fields: [
                {
                  kind: "select",
                  name: "principal_effect[access_blocking]",
                  label: t("base.org.admin.fields.access_blocking"),
                  value: "true",
                  options: %w(true false).map { |value| { value: value, label: value } },
                },
              ],
              acknowledgement: t("base.org.admin.enforcement.approve_acknowledgement"),
              submit_label: t("base.org.admin.enforcement.approve_submit"),
              errors: errors,
            )
          end
        end
      end
    end
  end
end
