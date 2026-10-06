# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      module Visitors
        # adr/operator-capability-authorization.md, Support: forced revocation of an com-realm
        # Visitor's sessions. It ends the sessions that exist when the revocation reads them; it is
        # not an access lock, so the Visitor may sign in again afterwards.
        #
        # Order: authenticate, load the target, authorize the capability, then Step-Up. An operator
        # without the capability is refused before any Step-Up ceremony can start.
        class RevocationsController < Base::Org::ApplicationController
          include ::SurfaceInertiaPage
          include ::OrgAdministrationPage
          include ::OrgAdministrativeAudit
          include ::OrgSupportSessionRevocationPage

          AUTHENTICATION_MODE = :private
          REALM = "com"
          STEP_UP_SCOPE = "support_session_revoke"
          declare_authentication_mode! :private

          before_action :no_store
          before_action :set_visitor
          before_action :authorize_revocation!, only: :new
          before_action :authorize_result!, only: :show
          before_action :require_revocation_step_up!, only: :new

          public

          def show
            chronicle = recorded_revocation!(@visitor)
            render inertia: "base/org/support/revocations/show",
                   props: revocation_result_props(
                     chronicle: chronicle,
                     target: @visitor,
                     realm: REALM,
                     up_link: { label: @visitor.public_id, href: base_org_support_visitor_path(@visitor.public_id) },
                   )
          end

          def new
            render inertia: "base/org/support/revocations/new", props: confirmation_props
          end

          def create
            authorize!(@visitor, to: :revoke_sessions?, with: SupportVisitorPolicy)
            return unless require_revocation_step_up!

            reason_code, ticket_id, operation_id = revocation_input!
            chronicle =
              audited_administrative_operation(
                operation_id: operation_id,
                action: AUDIT_ACTION,
                subject: @visitor,
                reason_code: reason_code,
                metadata: revocation_audit_metadata(target: @visitor, realm: REALM, ticket_id: ticket_id),
                changeset: revocation_audit_changeset(@visitor),
              ) do
                result = AccountSessionRevocation.purge!(
                  account: @visitor, operator: current_operator, reason_code: reason_code, ticket_id: ticket_id,
                )
                { revoked_count: result.revoked_count, account_access_event_id: result.event.id }
              end
            redirect_to(
              base_org_support_visitor_revocation_path(@visitor.public_id, chronicle.event_uuid),
              status: :see_other,
            )
          rescue InvalidRevocationInput => e
            render inertia: "base/org/support/revocations/new",
                   props: confirmation_props(errors: e.errors, values: submitted_values),
                   status: :unprocessable_content
          rescue OrgAdministrativeAudit::OperationConflictError
            render inertia: "base/org/support/revocations/new",
                   props: confirmation_props(errors: { operation_id: t("base.org.admin.errors.conflict") }),
                   status: :conflict
          rescue OrgAdministrativeAudit::IntentUnavailableError
            render inertia: "base/org/support/revocations/new",
                   props: confirmation_props(errors: { base: t("base.org.admin.errors.audit_unavailable") }),
                   status: :service_unavailable
          end

          private

          def no_store
            response.headers["Cache-Control"] = "private, no-store"
          end

          def set_visitor
            @visitor = Visitor.find_by!(public_id: params.expect(:visitor_id))
          end

          def authorize_revocation!
            authorize!(@visitor, to: :revoke_sessions?, with: SupportVisitorPolicy)
          end

          def authorize_result!
            authorize!(@visitor, to: :show?, with: SupportVisitorPolicy)
          end

          # True when Step-Up is satisfied; otherwise the Step-Up response has been rendered.
          def require_revocation_step_up!
            require_step_up!(scope: STEP_UP_SCOPE)
            !performed?
          end

          def confirmation_props(errors: {}, values: {})
            revocation_confirmation_props(
              target: @visitor,
              realm: REALM,
              errors: errors,
              values: values,
              action_path: base_org_support_visitor_revocations_path(@visitor.public_id),
              up_link: { label: @visitor.public_id, href: base_org_support_visitor_path(@visitor.public_id) },
            )
          end

          def submitted_values
            { reason_code: params[:reason_code].to_s, ticket_id: params[:ticket_id].to_s }
          end
        end
      end
    end
  end
end
