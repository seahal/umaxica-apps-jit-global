# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Iam
      # adr/operator-capability-authorization.md, IAM: capability grants. Granting needs
      # iam.capability.grant, the granted capability itself (delegation never widens), a target
      # other than the granter, and Step-Up. IAM capabilities are not grantable here at all.
      class GrantsController < Base::Org::ApplicationController
        include ::SurfaceInertiaPage
        include ::OrgAdministrationPage
        include ::OrgAdministrativeAudit

        AUTHENTICATION_MODE = :private
        AUDIT_ACTION = "iam.capability.granted"
        STEP_UP_SCOPE = "operator_capability"
        DURATIONS = { "7" => 7.days, "30" => 30.days, "90" => 90.days, "180" => 180.days }.freeze
        TICKET_ID_FORMAT = OperatorCapabilityGrant::TICKET_ID_FORMAT
        declare_authentication_mode! :private

        before_action :authenticate_operator!
        before_action :no_store
        before_action :authorize_index!, only: %i(index show)
        before_action :authorize_grant_screen!, only: :new
        before_action :require_grant_step_up!, only: :new

        public

        def index
          query = admin_query
          relation = OperatorCapabilityGrant.includes(:operator).order(created_at: :desc, id: :desc)
          relation = relation.joins(:operator).where(operators: { public_id: query }) if query
          grants, page, more = admin_paginate(relation)

          render inertia: "base/org/iam/grants/index",
                 props: {
                   title: t("base.org.admin.grants.title"),
                   up_link: { label: t("base.org.admin.iam.title"), href: base_org_iam_index_path },
                   context: admin_context(realm: nil),
                   columns: [t("base.org.admin.fields.grant_id"), t("base.org.admin.fields.operator"),
                             t("base.org.admin.fields.capability"), t("base.org.admin.fields.state"),
                             t("base.org.admin.fields.expires_at"),],
                   rows: grants.map { |grant| grant_row(grant) },
                   empty_message: t("base.org.admin.grants.empty"),
                   search: {
                     action: base_org_iam_grants_path,
                     label: t("base.org.admin.search.operator_public_id"),
                     name: "q",
                     value: query.to_s,
                     submit_label: t("base.org.admin.search.submit"),
                     maxlength: OrgAdministrationPage::MAX_QUERY_LENGTH,
                   },
                   pagination: admin_pagination_links(
                     page: page,
                     more: more,
                     path_builder: ->(number) {
                       base_org_iam_grants_path(q: query, page: number)
                     },
                   ),
                   actions: grantable_capabilities.any? ? [{ label: t("base.org.admin.grants.new_action"),
                                                             href: new_base_org_iam_grant_path, }] : [],
                 }
        end

        def show
          grant = OperatorCapabilityGrant.includes(:operator, :granted_by_operator, :revoked_by_operator)
            .find_by!(public_id: params.expect(:id))
          render inertia: "base/org/iam/grants/show",
                 props: {
                   title: t("base.org.admin.grants.show_title", public_id: grant.public_id),
                   up_link: { label: t("base.org.admin.grants.title"), href: base_org_iam_grants_path },
                   context: admin_context(realm: nil),
                   fields: grant_fields(grant),
                   actions: grant_actions(grant),
                   sections: [],
                 }
        end

        def new
          render inertia: "base/org/iam/grants/new", props: confirmation_props
        end

        def create
          authorize!(OperatorCapabilityGrant, to: :grant_screen?, with: OperatorCapabilityGrantPolicy)
          return unless require_grant_step_up!

          input = grant_input!
          grant = OperatorCapabilityGrant.new(operator: input.fetch(:operator), capability: input.fetch(:capability))
          authorize!(grant, to: :create?, with: OperatorCapabilityGrantPolicy)

          chronicle =
            audited_administrative_operation(
              operation_id: input.fetch(:operation_id),
              action: AUDIT_ACTION,
              subject: input.fetch(:operator),
              reason_code: input.fetch(:reason_code),
              metadata: { capability: input.fetch(:capability),
                          ticket_id: input.fetch(:ticket_id),
                          subject_public_id: input.fetch(:operator).public_id, },
              changeset: {},
            ) do
              issued = OperatorCapabilityGrant.issue!(
                operator: input.fetch(:operator),
                granted_by: current_operator,
                capability: input.fetch(:capability),
                reason_code: input.fetch(:reason_code),
                ticket_id: input.fetch(:ticket_id),
                duration: input.fetch(:duration),
              )
              { grant_public_id: issued.public_id, expires_at: issued.expires_at.iso8601 }
            end
          redirect_to(granted_path(chronicle), status: :see_other)
        rescue InvalidGrantInput => e
          render inertia: "base/org/iam/grants/new",
                 props: confirmation_props(errors: e.errors),
                 status: :unprocessable_content
        rescue OrgAdministrativeAudit::OperationConflictError
          render inertia: "base/org/iam/grants/new",
                 props: confirmation_props(errors: { operation_id: t("base.org.admin.errors.conflict") }),
                 status: :conflict
        rescue OrgAdministrativeAudit::IntentUnavailableError
          render inertia: "base/org/iam/grants/new",
                 props: confirmation_props(errors: { base: t("base.org.admin.errors.audit_unavailable") }),
                 status: :service_unavailable
        end

        class InvalidGrantInput < StandardError
          attr_reader :errors

          def initialize(errors)
            @errors = errors
            super("invalid grant input")
          end
        end

        private

        def no_store
          response.headers["Cache-Control"] = "private, no-store"
        end

        def authorize_index!
          authorize!(OperatorCapabilityGrant, to: :index?, with: OperatorCapabilityGrantPolicy)
        end

        # The screen itself needs the grant capability; the specific target and capability are
        # authorized again in `create` once they are known.
        def authorize_grant_screen!
          authorize!(OperatorCapabilityGrant, to: :grant_screen?, with: OperatorCapabilityGrantPolicy)
        end

        # True when Step-Up is satisfied; otherwise the Step-Up response has been rendered.
        def require_grant_step_up!
          require_step_up!(scope: STEP_UP_SCOPE)
          !performed?
        end

        # The capabilities this operator may delegate: the ones they hold, minus IAM.
        def grantable_capabilities
          (OperatorCapabilityGrant::CAPABILITIES - OperatorCapabilityGrant::BOOTSTRAP_ONLY_CAPABILITIES)
            .select { |capability| current_operator.capability?(capability) }
        end

        def grant_input!
          errors = {}
          operator = grant_target_operator(errors)
          capability = listed_value(
            :capability, OperatorCapabilityGrant::CAPABILITIES, errors,
            t("base.org.admin.errors.capability"),
          )
          reason_code = listed_value(
            :reason_code, OperatorCapabilityGrant::DELEGATED_GRANT_REASON_CODES, errors,
            t("base.org.admin.errors.reason_code"),
          )
          duration_key = listed_value(:duration_days, DURATIONS.keys, errors, t("base.org.admin.errors.duration"))
          ticket_id = grant_ticket_id(errors)
          operation_id = params[:operation_id]
          unless operation_id.is_a?(String) && OrgAdministrativeAudit::OPERATION_ID_FORMAT.match?(operation_id)
            errors[:operation_id] = t("base.org.admin.errors.operation_id")
          end
          raise InvalidGrantInput, errors if errors.any?

          { operator:, capability:, reason_code:, duration: DURATIONS.fetch(duration_key), ticket_id:, operation_id: }
        end

        # An existing, eligible operator other than the granter, named by a well-formed public id.
        def grant_target_operator(errors)
          public_id = params[:operator_public_id]
          operator = Operator.find_by(public_id: public_id) if public_id.is_a?(String) &&
            Operator::PUBLIC_ID_FORMAT.match?(public_id)
          if operator.nil? || !operator.capability_eligible?
            errors[:operator_public_id] = t("base.org.admin.errors.operator")
          elsif operator.id == current_operator.id
            errors[:operator_public_id] = t("base.org.admin.errors.self_grant")
          end
          operator
        end

        # The submitted value when it is exactly one of the listed strings; otherwise records `message`.
        def listed_value(key, allowed, errors, message)
          value = params[key]
          return value if value.is_a?(String) && allowed.include?(value)

          errors[key] = message
          nil
        end

        def grant_ticket_id(errors)
          ticket_id = params[:ticket_id]
          return nil if ticket_id.nil? || ticket_id == ""
          return ticket_id if ticket_id.is_a?(String) && TICKET_ID_FORMAT.match?(ticket_id)

          errors[:ticket_id] = t("base.org.admin.errors.ticket_id")
          nil
        end

        def granted_path(chronicle)
          grant_public_id = chronicle.changeset["grant_public_id"]
          return base_org_iam_grant_path(grant_public_id) if grant_public_id.present?

          # The audit row could not record the result; the grant list is the place to verify it.
          base_org_iam_grants_path(q: params[:operator_public_id])
        end

        def grant_state(grant)
          if grant.revoked? then t("base.org.admin.grants.states.revoked")
          elsif grant.in_force? then t("base.org.admin.grants.states.in_force")
          elsif grant.starts_at > Time.current then t("base.org.admin.grants.states.pending")
          else t("base.org.admin.grants.states.expired")
          end
        end

        def grant_row(grant)
          {
            key: grant.public_id,
            cells: [grant.public_id, grant.operator.public_id, grant.capability, grant_state(grant),
                    admin_time(grant.expires_at),],
            href: base_org_iam_grant_path(grant.public_id),
          }
        end

        def grant_fields(grant)
          [
            { term: t("base.org.admin.fields.grant_id"), description: grant.public_id },
            { term: t("base.org.admin.fields.operator"), description: grant.operator.public_id },
            { term: t("base.org.admin.fields.capability"), description: grant.capability },
            { term: t("base.org.admin.fields.state"), description: grant_state(grant) },
            { term: t("base.org.admin.fields.origin"), description: grant.origin },
            { term: t("base.org.admin.fields.granted_by"),
              description: grant.granted_by_operator&.public_id || t("base.org.admin.values.bootstrap"), },
            { term: t("base.org.admin.fields.reason_code"), description: grant.reason_code },
            { term: t("base.org.admin.fields.ticket_id"),
              description: grant.ticket_id || t("base.org.admin.values.none"), },
            { term: t("base.org.admin.fields.starts_at"), description: admin_time(grant.starts_at) },
            { term: t("base.org.admin.fields.expires_at"), description: admin_time(grant.expires_at) },
            { term: t("base.org.admin.fields.revoked_at"), description: admin_time(grant.revoked_at) },
            { term: t("base.org.admin.fields.revoked_by"),
              description: grant.revoked_by_operator&.public_id || t("base.org.admin.values.none"), },
          ]
        end

        def grant_actions(grant)
          return [] unless allowed_to?(:revoke?, grant, with: OperatorCapabilityGrantPolicy)

          [{ label: t("base.org.admin.grants.revoke_action"),
             href: new_base_org_iam_grant_revocation_path(grant.public_id), }]
        end

        def confirmation_props(errors: {})
          {
            title: t("base.org.admin.grants.new_title"),
            up_link: { label: t("base.org.admin.grants.title"), href: base_org_iam_grants_path },
            context: admin_context(realm: nil),
            target: [],
            effect: t("base.org.admin.grants.effect"),
            action: base_org_iam_grants_path,
            fields: grant_form_fields,
            acknowledgement: t("base.org.admin.grants.acknowledgement"),
            submit_label: t("base.org.admin.grants.submit"),
            errors: errors,
          }
        end

        def grant_form_fields
          [
            {
              kind: "text",
              name: "operator_public_id",
              label: t("base.org.admin.fields.operator"),
              value: params[:operator_public_id].to_s,
              maxlength: Operator::PUBLIC_ID_LENGTH,
              required: true,
            },
            {
              kind: "select",
              name: "capability",
              label: t("base.org.admin.fields.capability"),
              value: "",
              options: grantable_capabilities.map { |capability|
                { value: capability, label: capability }
              },
            },
            {
              kind: "select",
              name: "reason_code",
              label: t("base.org.admin.fields.reason_code"),
              value: "",
              options: OperatorCapabilityGrant::DELEGATED_GRANT_REASON_CODES.map { |code|
                { value: code, label: code }
              },
            },
            {
              kind: "select",
              name: "duration_days",
              label: t("base.org.admin.fields.duration_days"),
              value: "30",
              options: DURATIONS.keys.map { |days| { value: days, label: days } },
            },
            { kind: "text",
              name: "ticket_id",
              label: t("base.org.admin.fields.ticket_id"),
              value: "",
              maxlength: 64,
              required: false, },
            { kind: "hidden", name: "operation_id", value: admin_operation_id },
          ]
        end
      end
    end
  end
end
