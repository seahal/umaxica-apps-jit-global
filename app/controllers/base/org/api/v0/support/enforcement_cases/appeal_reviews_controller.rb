# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        module Support
          module EnforcementCases
            # adr/unified-enforcement.md, Appeal: the reviewer must differ from the applying and the
            # approving operator (EnforcementAppeal#resolve!). An approved appeal ends the Case through
            # the same refcounted release path as any other ending.
            class AppealReviewsController < ActionController::API
              include ::DefaultNoStore

              prepend_before_action :apply_default_no_store
              include ActionController::MimeResponds
              include AbstractController::Translation
              include ActionPolicy::Controller
              include ::ActorSupport
              include ::AvatarAuthorityApiEndpoint
              include ::OwnerPageResponses

              include ::EnforcementCaseRealmResolvable
              include ::OrgAdministrationPage
              include ::OrgEnforcementCasePage

              AVATAR_SURFACE = "org"

              authorize :user, through: :avatar_actor
              AUTHENTICATION_MODE = :open
              STEP_UP_SCOPE = "enforcement_case_review_appeal"
              around_action :with_actor_lifecycle
              before_action :authenticate_avatar_caller!
              before_action :set_current_actor
              before_action :apply_browser_context
              rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
              rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
              rescue_from ActionController::BadRequest, with: :render_bad_request

              before_action :no_store
              before_action :set_enforcement_case
              before_action :authorize_review!, only: :new
              before_action :require_enforcement_step_up!, only: :new

              public

              def new
                render inertia: "base/org/support/enforcement_cases/appeal_reviews/new", props: confirmation_props
              end

              def create
                authorize!(@enforcement_case, with: EnforcementCasePolicy, to: :review_appeal?)
                return unless require_enforcement_step_up!

                appeal = @enforcement_case.appeal
                raise ActiveRecord::RecordNotFound, "appeal not found" unless appeal

                appeal.resolve!(
                  reviewer_operator_public_id: current_operator.public_id,
                  resolution_code: params.expect(:resolution_code),
                )
                respond_to do |format|
                  format.json { render json: { public_id: appeal.public_id, state: appeal.state }, status: :ok }
                  format.html { redirect_to(enforcement_case_path_for(@enforcement_case), status: :see_other) }
                end
              rescue EnforcementAppeal::ReviewerSeparationError, EnforcementAppeal::InvalidResolutionError,
                     ActiveRecord::RecordInvalid, ArgumentError => e
                respond_to do |format|
                  format.json { render json: { error: e.message }, status: :unprocessable_content }
                  format.html do
                    render inertia: "base/org/support/enforcement_cases/appeal_reviews/new",
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

              def authorize_review!
                authorize!(@enforcement_case, with: EnforcementCasePolicy, to: :review_appeal?)
              end

              def confirmation_props(errors: {})
                enforcement_confirmation_props(
                  @enforcement_case,
                  title: t("base.org.admin.enforcement.appeal_review_title"),
                  effect: t("base.org.admin.enforcement.appeal_review_effect"),
                  action: request.path.delete_suffix("/new"),
                  fields: [
                    {
                      kind: "select",
                      name: "resolution_code",
                      label: t("base.org.admin.fields.resolution_code"),
                      value: "rejected",
                      options: EnforcementAppeal::RESOLUTION_CODES.map { |value| { value: value, label: value } },
                    },
                  ],
                  acknowledgement: t("base.org.admin.enforcement.appeal_review_acknowledgement"),
                  submit_label: t("base.org.admin.enforcement.appeal_review_submit"),
                  errors: errors,
                )
              end
            end
          end
        end
      end
    end
  end
end
