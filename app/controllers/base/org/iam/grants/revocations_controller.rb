# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Iam
      module Grants
        # adr/operator-capability-authorization.md, IAM: revoking one capability grant. The model
        # refuses to revoke the last in-force holder of a continuity capability.
        class RevocationsController < Base::Org::ApplicationController
          include ::SurfaceInertiaPage
          include ::OrgAdministrationPage
          include ::OrgAdministrativeAudit

          AUTHENTICATION_MODE = :private
          AUDIT_ACTION = "iam.capability.revoked"
          STEP_UP_SCOPE = "operator_capability"
          declare_authentication_mode! :private

          before_action :no_store
          before_action :set_grant
          before_action :authorize_revocation!, only: :new
          before_action :require_revocation_step_up!, only: :new

          public

          def new
            render inertia: "base/org/iam/grants/revocations/new", props: confirmation_props
          end

          def create
            authorize!(@grant, to: :revoke?, with: OperatorCapabilityGrantPolicy)
            return unless require_revocation_step_up!

            reason_code = params[:reason_code]
            operation_id = params[:operation_id]
            errors = {}
            unless reason_code.is_a?(String) && OperatorCapabilityGrant::REVOKE_REASON_CODES.include?(reason_code)
              errors[:reason_code] = t("base.org.admin.errors.reason_code")
            end
            unless operation_id.is_a?(String) && OrgAdministrativeAudit::OPERATION_ID_FORMAT.match?(operation_id)
              errors[:operation_id] = t("base.org.admin.errors.operation_id")
            end
            return render_confirmation(errors, :unprocessable_content) if errors.any?

            audited_administrative_operation(
              operation_id: operation_id,
              action: AUDIT_ACTION,
              subject: @grant.operator,
              reason_code: reason_code,
              metadata: { capability: @grant.capability,
                          grant_public_id: @grant.public_id,
                          subject_public_id: @grant.operator.public_id, },
              changeset: { before: { revoked: false } },
            ) do
              @grant.revoke!(by: current_operator, reason_code: reason_code)
              { revoked: true }
            end
            redirect_to(base_org_iam_grant_path(@grant.public_id), status: :see_other)
          rescue OperatorCapabilityGrant::LastCapabilityHolderError
            render_confirmation({ base: t("base.org.admin.errors.last_holder") }, :unprocessable_content)
          rescue OperatorCapabilityGrant::AlreadyRevokedError, OrgAdministrativeAudit::OperationConflictError
            render_confirmation({ base: t("base.org.admin.errors.conflict") }, :conflict)
          rescue OrgAdministrativeAudit::IntentUnavailableError
            render_confirmation({ base: t("base.org.admin.errors.audit_unavailable") }, :service_unavailable)
          end

          private

          def no_store
            response.headers["Cache-Control"] = "private, no-store"
          end

          def set_grant
            @grant = OperatorCapabilityGrant.includes(:operator).find_by!(public_id: params.expect(:grant_id))
          end

          def authorize_revocation!
            authorize!(@grant, to: :revoke?, with: OperatorCapabilityGrantPolicy)
          end

          # True when Step-Up is satisfied; otherwise the Step-Up response has been rendered.
          def require_revocation_step_up!
            require_step_up!(scope: STEP_UP_SCOPE)
            !performed?
          end

          def render_confirmation(errors, status)
            render inertia: "base/org/iam/grants/revocations/new",
                   props: confirmation_props(errors: errors),
                   status: status
          end

          def confirmation_props(errors: {})
            {
              title: t("base.org.admin.grants.revoke_title"),
              up_link: { label: @grant.public_id, href: base_org_iam_grant_path(@grant.public_id) },
              context: admin_context(realm: nil),
              target: [
                { term: t("base.org.admin.fields.grant_id"), description: @grant.public_id },
                { term: t("base.org.admin.fields.operator"), description: @grant.operator.public_id },
                { term: t("base.org.admin.fields.capability"), description: @grant.capability },
                { term: t("base.org.admin.fields.expires_at"), description: admin_time(@grant.expires_at) },
              ],
              effect: t("base.org.admin.grants.revoke_effect"),
              action: base_org_iam_grant_revocation_path(@grant.public_id),
              fields: [
                {
                  kind: "select",
                  name: "reason_code",
                  label: t("base.org.admin.fields.reason_code"),
                  value: "",
                  options: OperatorCapabilityGrant::REVOKE_REASON_CODES.map { |code| { value: code, label: code } },
                },
                { kind: "hidden", name: "operation_id", value: admin_operation_id },
              ],
              acknowledgement: t("base.org.admin.grants.revoke_acknowledgement"),
              submit_label: t("base.org.admin.grants.revoke_submit"),
              errors: errors,
            }
          end
        end
      end
    end
  end
end
