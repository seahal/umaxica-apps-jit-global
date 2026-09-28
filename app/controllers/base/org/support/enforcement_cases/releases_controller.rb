# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      module EnforcementCases
        # adr/unified-enforcement.md, Administrative Access Lock integration / Break-glass, and
        # adr/operator-capability-authorization.md. Ending a Case releases the principal's access
        # lock only when no other in-force Case still blocks them (EnforcementCaseEndOperation's
        # refcount), and never revives a session, token, or Step-Up freshness.
        #
        # A permanent ban and a break-glass-only Case need a break-glass release with a second
        # approver. That flow is not provided through the console, so those Cases are refused here
        # rather than released under a weaker control than the one that applied them.
        class ReleasesController < Base::Org::ApplicationController
          include ::SurfaceInertiaPage
          include ::EnforcementCaseRealmResolvable
          include ::OrgAdministrationPage
          include ::OrgEnforcementCasePage

          AUTHENTICATION_MODE = :private
          STEP_UP_SCOPE = "enforcement_case_release"

          declare_authentication_mode! :private
          before_action :authenticate_operator!
          before_action :no_store
          before_action :set_enforcement_case
          before_action :authorize_release!, only: :new
          before_action :require_enforcement_step_up!, only: :new

          public

          def new
            return render_rejection(
              t("base.org.admin.errors.break_glass_required"),
              :unprocessable_content,
            ) if break_glass_required?

            render inertia: "base/org/support/enforcement_cases/releases/new", props: confirmation_props
          end

          def create
            authorize!(@enforcement_case, with: EnforcementCasePolicy, to: :release?)
            return unless require_enforcement_step_up!

            return render_rejection(
              t("base.org.admin.errors.break_glass_required"),
              :unprocessable_content,
            ) if break_glass_required?

            reason = params[:reason]
            unless reason.is_a?(String) && OrgEnforcementCasePage::OPERATOR_RELEASE_REASONS.include?(reason)
              return render_rejection(t("base.org.admin.errors.release_reason"), :unprocessable_content)
            end
            unless @enforcement_case.state == "active"
              return render_rejection(t("base.org.admin.errors.conflict"), :conflict)
            end

            EnforcementCaseEndOperation.call(
              enforcement_case: @enforcement_case,
              reason: reason,
              ended_by_operator_public_id: current_operator.public_id,
            )
            respond_to do |format|
              format.json do
                render json: { public_id: @enforcement_case.public_id,
                               state: @enforcement_case.state,
                               ended_at: @enforcement_case.ended_at, },
                       status: :ok
              end
              format.html { redirect_to(enforcement_case_path_for(@enforcement_case), status: :see_other) }
            end
          rescue ActiveRecord::RecordInvalid, ArgumentError => e
            render_rejection(e.message, :unprocessable_content)
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

          def authorize_release!
            authorize!(@enforcement_case, with: EnforcementCasePolicy, to: :release?)
          end

          def break_glass_required?
            @enforcement_case.kind == "permanent_ban" || @enforcement_case.release_mode == "break_glass_only"
          end

          def render_rejection(message, status)
            respond_to do |format|
              format.json { render json: { error: message }, status: status }
              format.html do
                render inertia: "base/org/support/enforcement_cases/releases/new",
                       props: confirmation_props(errors: { base: message }),
                       status: status
              end
            end
          end

          def confirmation_props(errors: {})
            enforcement_confirmation_props(
              @enforcement_case,
              title: t("base.org.admin.enforcement.release_title"),
              effect: t("base.org.admin.enforcement.release_effect"),
              action: request.path.delete_suffix("/new"),
              fields: [
                {
                  kind: "select",
                  name: "reason",
                  label: t("base.org.admin.fields.end_reason"),
                  value: "revoked",
                  options: OrgEnforcementCasePage::OPERATOR_RELEASE_REASONS.map { |value|
                    { value: value, label: value }
                  },
                },
              ],
              acknowledgement: t("base.org.admin.enforcement.release_acknowledgement"),
              submit_label: t("base.org.admin.enforcement.release_submit"),
              errors: errors,
            )
          end
        end
      end
    end
  end
end
