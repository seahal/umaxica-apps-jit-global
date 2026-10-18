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
        include ::OrgAdminRelay

        AUTHENTICATION_MODE = :private
        AUDIT_ACTION = "iam.capability.granted"
        STEP_UP_SCOPE = "operator_capability"
        DURATIONS = { "7" => 7.days, "30" => 30.days, "90" => 90.days, "180" => 180.days }.freeze
        TICKET_ID_FORMAT = OperatorCapabilityGrant::TICKET_ID_FORMAT
        declare_authentication_mode! :private

        GRANT_STATE_KEYS = {
          "revoked" => "base.org.admin.grants.states.revoked",
          "in_force" => "base.org.admin.grants.states.in_force",
          "pending" => "base.org.admin.grants.states.pending",
          "expired" => "base.org.admin.grants.states.expired",
        }.freeze

        before_action :no_store

        public

        # R5-WU12: grants are read, issued and revoked by the IAM owner over HTTPS.
        def index
          result = org_admin_result!(
            org_admin_authority.get(
              "/iam/grants",
              { q: params[:q], page: params[:page] }.compact,
            ),
          )
          return unless result

          query = params[:q].presence
          data = result.data
          render inertia: "base/org/iam/grants/index",
                 props: {
                   title: t("base.org.admin.grants.title"),
                   up_link: { label: t("base.org.admin.iam.title"), href: base_org_iam_index_path },
                   context: admin_context(realm: nil),
                   columns: [t("base.org.admin.fields.grant_id"), t("base.org.admin.fields.operator"),
                             t("base.org.admin.fields.capability"), t("base.org.admin.fields.state"),
                             t("base.org.admin.fields.expires_at"),],
                   rows: data.fetch("grants").map { |grant| grant_row(grant) },
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
                     page: data.fetch("page"), more: data["next_page"].present?,
                     path_builder: ->(number) { base_org_iam_grants_path(q: query, page: number) },
                   ),
                   actions: data.fetch("can_grant") ? [{ label: t("base.org.admin.grants.new_action"),
                                                         href: new_base_org_iam_grant_path, }] : [],
                 }
        end

        def show
          result = org_admin_result!(org_admin_authority.get("/iam/grants/#{ERB::Util.url_encode(params.expect(:id))}"))
          return unless result

          grant = result.data.fetch("grant")
          render inertia: "base/org/iam/grants/show",
                 props: {
                   title: t("base.org.admin.grants.show_title", public_id: grant.fetch("public_id")),
                   up_link: { label: t("base.org.admin.grants.title"), href: base_org_iam_grants_path },
                   context: admin_context(realm: nil),
                   fields: grant_fields(grant),
                   actions: revoke_actions(grant, result.data.fetch("can_revoke")),
                   sections: [],
                 }
        end

        def new
          result = org_admin_result!(org_admin_authority.get("/iam/grant-screen"))
          return unless result

          render inertia: "base/org/iam/grants/new", props: confirmation_props(result.data)
        end

        def create
          keys = %i(operator_public_id capability reason_code duration_days ticket_id operation_id)
          result = org_admin_result!(org_admin_authority.post("/iam/grants", params.slice(*keys).permit(*keys).to_h))
          return unless result

          if result.ok?
            redirect_to(granted_path(result.data["grant_public_id"]), status: :see_other)
          else
            screen = org_admin_authority.get("/iam/grant-screen").data || {}
            render inertia: "base/org/iam/grants/new", props: confirmation_props(screen, errors: result.errors),
                   status: org_admin_status(result)
          end
        end

        private

        def no_store
          response.headers["Cache-Control"] = "private, no-store"
        end

        def granted_path(grant_public_id)
          return base_org_iam_grant_path(grant_public_id) if grant_public_id.present?

          # The audit row could not record the result; the grant list is the place to verify it.
          base_org_iam_grants_path(q: params[:operator_public_id])
        end

        def grant_state(state)
          t(GRANT_STATE_KEYS.fetch(state))
        end

        def revoke_actions(grant, can_revoke)
          return [] unless can_revoke

          [{ label: t("base.org.admin.grants.revoke_action"),
             href: new_base_org_iam_grant_revocation_path(grant.fetch("public_id")), }]
        end

        def owner_time(value)
          admin_time(value && Time.zone.parse(value))
        end

        def grant_row(grant)
          {
            key: grant.fetch("public_id"),
            cells: [grant.fetch("public_id"), grant.fetch("operator_public_id"), grant.fetch("capability"),
                    grant_state(grant.fetch("state")), owner_time(grant["expires_at"]),],
            href: base_org_iam_grant_path(grant.fetch("public_id")),
          }
        end

        def grant_fields(grant)
          [
            { term: t("base.org.admin.fields.grant_id"), description: grant.fetch("public_id") },
            { term: t("base.org.admin.fields.operator"), description: grant.fetch("operator_public_id") },
            { term: t("base.org.admin.fields.capability"), description: grant.fetch("capability") },
            { term: t("base.org.admin.fields.state"), description: grant_state(grant.fetch("state")) },
            { term: t("base.org.admin.fields.origin"), description: grant["origin"] },
            { term: t("base.org.admin.fields.granted_by"),
              description: grant["granted_by_public_id"] || t("base.org.admin.values.bootstrap"), },
            { term: t("base.org.admin.fields.reason_code"), description: grant["reason_code"] },
            { term: t("base.org.admin.fields.ticket_id"),
              description: grant["ticket_id"] || t("base.org.admin.values.none"), },
            { term: t("base.org.admin.fields.starts_at"), description: owner_time(grant["starts_at"]) },
            { term: t("base.org.admin.fields.expires_at"), description: owner_time(grant["expires_at"]) },
            { term: t("base.org.admin.fields.revoked_at"), description: owner_time(grant["revoked_at"]) },
            { term: t("base.org.admin.fields.revoked_by"),
              description: grant["revoked_by_public_id"] || t("base.org.admin.values.none"), },
          ]
        end

        def confirmation_props(screen, errors: {})
          {
            title: t("base.org.admin.grants.new_title"),
            up_link: { label: t("base.org.admin.grants.title"), href: base_org_iam_grants_path },
            context: admin_context(realm: nil),
            target: [],
            effect: t("base.org.admin.grants.effect"),
            action: base_org_iam_grants_path,
            fields: grant_form_fields(screen),
            acknowledgement: t("base.org.admin.grants.acknowledgement"),
            submit_label: t("base.org.admin.grants.submit"),
            errors: errors,
          }
        end

        def grant_form_fields(screen)
          [
            { kind: "text",
              name: "operator_public_id",
              label: t("base.org.admin.fields.operator"),
              value: params[:operator_public_id].to_s,
              maxlength: Operator::PUBLIC_ID_LENGTH,
              required: true, },
            { kind: "select",
              name: "capability",
              label: t("base.org.admin.fields.capability"),
              value: "",
              options: Array(screen["grantable_capabilities"]).map { |capability|
                { value: capability, label: capability }
              }, },
            { kind: "select",
              name: "reason_code",
              label: t("base.org.admin.fields.reason_code"),
              value: "",
              options: Array(screen["reason_codes"]).map { |code| { value: code, label: code } }, },
            { kind: "select",
              name: "duration_days",
              label: t("base.org.admin.fields.duration_days"),
              value: "30",
              options: Array(screen["durations"]).map { |days| { value: days, label: days } }, },
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
