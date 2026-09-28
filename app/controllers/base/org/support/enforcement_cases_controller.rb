# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      # adr/unified-enforcement.md, Approval / Operator safety, and
      # adr/operator-capability-authorization.md. Noun-resource controller per
      # .agents/harnesses/rules/generic/routing.mdc -- no `ban`/`approve`/`release` actions here;
      # those are the nested `approval`, `release`, and `appeal_review` resources.
      #
      # Reading (index/show) needs only the realm's read capability. Applying (new/create) needs the
      # apply capability and the `enforcement_case_apply` Step-Up, checked in that order. The
      # applying operator and every approver are taken from the session, never from the request.
      class EnforcementCasesController < Base::Org::ApplicationController
        include ::SurfaceInertiaPage
        include ::EnforcementCaseRealmResolvable
        include ::OrgAdministrationPage
        include ::OrgEnforcementCasePage

        AUTHENTICATION_MODE = :private
        STEP_UP_SCOPE = "enforcement_case_apply"

        declare_authentication_mode! :private
        before_action :authenticate_operator!
        before_action :no_store
        before_action :authorize_enforcement_index!, only: :index
        before_action :set_enforcement_case, only: :show
        before_action :authorize_enforcement_create!, only: :new
        before_action :require_enforcement_step_up!, only: :new

        public

        def index
          principal_public_id = admin_query_for(:principal_public_id)
          relation = enforcement_case_class.order(created_at: :desc, id: :desc)
          relation = relation.where(principal_public_id: principal_public_id) if principal_public_id
          cases, page, more = admin_paginate(relation)

          respond_to do |format|
            format.json { render json: { enforcement_cases: cases.map { |c| enforcement_case_json(c) } } }
            format.html do
              render inertia: "base/org/support/enforcement_cases/index",
                     props: enforcement_index_props(cases, page, more, principal_public_id)
            end
          end
        end

        def show
          authorize!(@enforcement_case, with: EnforcementCasePolicy, to: :show?)
          respond_to do |format|
            format.json { render json: enforcement_case_json(@enforcement_case) }
            format.html do
              render inertia: "base/org/support/enforcement_cases/show",
                     props: enforcement_show_props(@enforcement_case)
            end
          end
        end

        def new
          principal = find_principal!(params[:principal_public_id])
          render inertia: "base/org/support/enforcement_cases/new", props: apply_confirmation_props(principal)
        end

        def create
          authorize!(enforcement_case_class.new, with: EnforcementCasePolicy, to: :create?)
          return unless require_enforcement_step_up!

          # Break-glass needs a second approver recorded from that approver's own session; the
          # console provides no such flow, so a request for it is refused rather than dropped.
          if ActiveModel::Type::Boolean.new.cast(params.dig(:enforcement_case, :break_glass))
            raise ArgumentError, t("base.org.admin.errors.break_glass_required")
          end

          enforcement_case = build_enforcement_case
          find_principal!(enforcement_case.principal_public_id)

          if enforcement_case.requires_approval?
            enforcement_case.state = "pending_approval"
            enforcement_case.save!
            enforcement_case.write_audit_event_once!(
              "approval_requested",
              actor_operator_public_id: current_operator.public_id,
            )
            return respond_created(enforcement_case, :accepted)
          end

          attach_requested_effects!(enforcement_case)
          EnforcementCaseApplyOperation.call(
            enforcement_case: enforcement_case,
            actor_operator_public_id: current_operator.public_id,
          )
          respond_created(enforcement_case, :created)
        rescue ActiveRecord::RecordInvalid, ArgumentError, ActionController::ParameterMissing => e
          respond_rejected(e)
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

        def authorize_enforcement_index!
          authorize!(enforcement_case_class.new, with: EnforcementCasePolicy, to: :index?)
        end

        def authorize_enforcement_create!
          authorize!(enforcement_case_class.new, with: EnforcementCasePolicy, to: :create?)
        end

        def set_enforcement_case
          @enforcement_case = enforcement_case_class.includes(:principal_effect, :appeal)
            .find_by!(public_id: params.expect(:id))
        end

        # The Case names a principal by public id. It must be an existing principal of this realm's
        # own class; a Case for an unknown or other-realm identifier is refused.
        def find_principal!(principal_public_id)
          unless principal_public_id.is_a?(String) && principal_public_id.present?
            raise ActionController::ParameterMissing, :principal_public_id
          end

          enforcement_case_class.principal_class.find_by!(public_id: principal_public_id)
        end

        def admin_query_for(key)
          value = params[key]
          return nil if value.nil? || value == ""
          raise ActionController::BadRequest, "#{key} is malformed" unless value.is_a?(String) &&
            OrgAdministrationPage::QUERY_FORMAT.match?(value) && value.length <= OrgAdministrationPage::MAX_QUERY_LENGTH

          value
        end

        def build_enforcement_case
          enforcement_case_class.new(
            enforcement_case_params.merge(applied_by_operator_public_id: current_operator.public_id),
          )
        end

        # Approver identities are never accepted from the request: a break-glass second approver is
        # recorded by the approval resource from its own authenticated session.
        def enforcement_case_params
          params.expect(
            enforcement_case: %i(kind duration_mode visibility release_mode effective_at expires_at
                                 review_due_at reason_code reason_note ticket_id principal_public_id),
          )
        end

        def respond_created(enforcement_case, status)
          respond_to do |format|
            format.json { render json: enforcement_case_json(enforcement_case), status: status }
            format.html do
              redirect_to(enforcement_case_path_for(enforcement_case), status: :see_other)
            end
          end
        end

        def respond_rejected(error)
          message =
            error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
          respond_to do |format|
            format.json { render json: { error: message }, status: :unprocessable_content }
            format.html do
              principal = enforcement_case_class.principal_class.find_by(
                public_id: params.dig(
                  :enforcement_case,
                  :principal_public_id,
                ).to_s,
              )
              raise ActiveRecord::RecordNotFound, "principal not found" if principal.nil?

              render inertia: "base/org/support/enforcement_cases/new",
                     props: apply_confirmation_props(principal, errors: { base: message }),
                     status: :unprocessable_content
            end
          end
        end

        # Only reached on the no-approval-required path (D12) -- a Case that
        # requires approval carries no effects until EnforcementCases::ApprovalsController
        # attaches and confirms them.
        def attach_requested_effects!(enforcement_case)
          if (attrs = params[:principal_effect]).present?
            enforcement_case.build_principal_effect(principal_effect_params(attrs, enforcement_case))
          end
          if (attrs = params[:authentication_method_effect]).present?
            enforcement_case.authentication_method_effects.build(
              authentication_method_effect_params(attrs, enforcement_case),
            )
          end
          if (attrs = params[:identifier_effect]).present?
            enforcement_case.identifier_effects.build(identifier_effect_params(attrs))
          end
        end

        # The effect always targets the Case's own principal; a differing principal in the effect
        # payload is ignored rather than trusted.
        def principal_effect_params(attrs, enforcement_case)
          attrs.permit(
            :access_blocking,
            :recovery_blocked,
            :reactivation_blocked,
            :withdrawal_purge_blocked,
            :principal_hard_delete_blocked,
            :profile_effect,
            :effective_at,
          ).to_h.merge(
            principal_public_id: enforcement_case.principal_public_id,
            effective_at: attrs[:effective_at].presence || Time.current,
          )
        end

        def authentication_method_effect_params(attrs, enforcement_case)
          attrs.permit(:authentication_method, :effect, :effective_at).to_h.merge(
            principal_public_id: enforcement_case.principal_public_id,
            effective_at: attrs[:effective_at].presence || Time.current,
          )
        end

        def identifier_effect_params(attrs)
          digest = EnforcementIdentifierDigest.for_email(
            realm: params[:realm],
            value: attrs[:email],
          ) if attrs[:email].present?
          digest ||= EnforcementIdentifierDigest.for_telephone(
            realm: params[:realm],
            value: attrs[:telephone],
          ) if attrs[:telephone].present?
          raise ArgumentError, "identifier_effect requires email or telephone" unless digest

          digest.merge(
            registration_blocked: ActiveModel::Type::Boolean.new.cast(attrs[:registration_blocked]),
            attachment_blocked: ActiveModel::Type::Boolean.new.cast(attrs[:attachment_blocked]),
            recovery_blocked: ActiveModel::Type::Boolean.new.cast(attrs[:recovery_blocked]),
            effective_at: Time.current,
          )
        end

        def enforcement_index_props(cases, page, more, principal_public_id)
          {
            title: t("base.org.admin.enforcement.title"),
            up_link: { label: t("base.org.admin.support.title"), href: base_org_support_index_path },
            context: admin_context(realm: enforcement_realm),
            columns: [t("base.org.admin.fields.case_id"), t("base.org.admin.fields.principal"),
                      t("base.org.admin.fields.kind"), t("base.org.admin.fields.state"),
                      t("base.org.admin.fields.created_at"),],
            rows: cases.map do |enforcement_case|
              {
                key: enforcement_case.public_id,
                cells: [enforcement_case.public_id, enforcement_case.principal_public_id, enforcement_case.kind,
                        enforcement_case.state, admin_time(enforcement_case.created_at),],
                href: enforcement_case_path_for(enforcement_case),
              }
            end,
            empty_message: t("base.org.admin.enforcement.empty"),
            search: {
              action: request.path,
              label: t("base.org.admin.search.principal_public_id"),
              name: "principal_public_id",
              value: principal_public_id.to_s,
              submit_label: t("base.org.admin.search.submit"),
              maxlength: OrgAdministrationPage::MAX_QUERY_LENGTH,
            },
            pagination: admin_pagination_links(
              page: page,
              more: more,
              path_builder: ->(number) {
                "#{enforcement_cases_path_for(enforcement_case_class.new)}?#{{
                  principal_public_id: principal_public_id, page: number,
                }.compact.to_query}"
              },
            ),
            actions: [],
          }
        end

        def apply_confirmation_props(principal, errors: {})
          {
            title: t("base.org.admin.enforcement.new_title"),
            up_link: { label: t("base.org.admin.enforcement.title"),
                       href: enforcement_cases_path_for(enforcement_case_class.new), },
            context: admin_context(realm: enforcement_realm),
            target: [
              { term: t("base.org.admin.fields.principal"), description: principal.public_id },
              { term: t("base.org.admin.fields.access_state"), description: principal.access_state },
            ],
            effect: t("base.org.admin.enforcement.apply_effect"),
            action: enforcement_cases_path_for(enforcement_case_class.new),
            fields: [
              { kind: "hidden", name: "enforcement_case[principal_public_id]", value: principal.public_id },
              select_field("enforcement_case[kind]", t("base.org.admin.fields.kind"), EnforcementCaseApplicable::KINDS),
              select_field("enforcement_case[duration_mode]", t("base.org.admin.fields.duration_mode"), EnforcementCaseApplicable::DURATION_MODES),
              select_field("enforcement_case[visibility]", t("base.org.admin.fields.visibility"), EnforcementCaseApplicable::VISIBILITIES),
              select_field("enforcement_case[release_mode]", t("base.org.admin.fields.release_mode"), EnforcementCaseApplicable::RELEASE_MODES),
              select_field("enforcement_case[reason_code]", t("base.org.admin.fields.reason_code"), AdministrativeAccessLockable::ADMIN_LOCK_REASON_CODES),
              {
                kind: "text",
                name: "enforcement_case[expires_at]",
                label: t("base.org.admin.fields.expires_at_iso"),
                value: "",
                maxlength: 40,
                required: false,
              },
              {
                kind: "text",
                name: "enforcement_case[ticket_id]",
                label: t("base.org.admin.fields.ticket_id"),
                value: "",
                maxlength: 64,
                required: false,
              },
              select_field(
                "principal_effect[access_blocking]", t("base.org.admin.fields.access_blocking"),
                %w(false true),
              ),
            ],
            acknowledgement: t("base.org.admin.enforcement.apply_acknowledgement"),
            submit_label: t("base.org.admin.enforcement.apply_submit"),
            errors: errors,
          }
        end

        def select_field(name, label, values)
          {
            kind: "select",
            name: name,
            label: label,
            value: values.first,
            options: values.map { |value| { value: value, label: value } },
          }
        end
      end
    end
  end
end
