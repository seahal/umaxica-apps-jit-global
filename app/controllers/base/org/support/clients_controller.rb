# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      # adr/operator-capability-authorization.md, Support: app-realm Clients, looked up only by their
      # public id. The page shows account and session state, never identifiers such as email
      # addresses, credentials, or tokens.
      class ClientsController < Base::Org::ApplicationController
        include ::SurfaceInertiaPage
        include ::OrgAdministrationPage
        include ::OrgAdminRelay

        AUTHENTICATION_MODE = :private
        REALM = "app"
        declare_authentication_mode! :private

        before_action :no_store

        public

        # R5-WU12: listed and decided by the org Support owner over HTTPS.
        def index
          result = org_admin_result!(
            org_admin_authority.get(
              "/support/app/accounts",
              { q: params[:q], page: params[:page] }.compact,
            ),
          )
          return unless result

          query = params[:q].presence
          data = result.data
          render inertia: "base/org/support/clients/index",
                 props: {
                   title: t("base.org.admin.clients.title"),
                   up_link: { label: t("base.org.admin.support.title"), href: base_org_support_index_path },
                   context: admin_context(realm: REALM),
                   columns: [t("base.org.admin.fields.public_id"), t("base.org.admin.fields.access_state"),
                             t("base.org.admin.fields.created_at"),],
                   rows: data.fetch("accounts").map { |row| client_row(row) },
                   empty_message: t("base.org.admin.clients.empty"),
                   search: {
                     action: base_org_support_clients_path,
                     label: t("base.org.admin.search.public_id"),
                     name: "q",
                     value: query.to_s,
                     submit_label: t("base.org.admin.search.submit"),
                     maxlength: OrgAdministrationPage::MAX_QUERY_LENGTH,
                   },
                   pagination: admin_pagination_links(
                     page: data.fetch("page"), more: data["next_page"].present?,
                     path_builder: ->(number) { base_org_support_clients_path(q: query, page: number) },
                   ),
                   actions: [],
                 }
        end

        def show
          result = org_admin_result!(org_admin_authority.get("/support/app/accounts/#{ERB::Util.url_encode(params.expect(:id))}"))
          return unless result

          data = result.data
          account = data.fetch("account")
          render inertia: "base/org/support/clients/show",
                 props: {
                   title: t("base.org.admin.clients.show_title", public_id: account.fetch("public_id")),
                   up_link: { label: t("base.org.admin.clients.title"), href: base_org_support_clients_path },
                   context: admin_context(realm: REALM),
                   fields: account_fields(account),
                   actions: client_actions(account.fetch("public_id"), data),
                   sections: [enforcement_section(data["cases"])].compact,
                 }
        end

        private

        def no_store
          response.headers["Cache-Control"] = "private, no-store"
        end

        def owner_time(value) = admin_time(value && Time.zone.parse(value))

        def client_row(row)
          {
            key: row.fetch("public_id"),
            cells: [row.fetch("public_id"), row.fetch("access_state"), owner_time(row["created_at"])],
            href: base_org_support_client_path(row.fetch("public_id")),
          }
        end

        def account_fields(account)
          [
            { term: t("base.org.admin.fields.public_id"), description: account.fetch("public_id") },
            { term: t("base.org.admin.fields.access_state"), description: account.fetch("access_state") },
            { term: t("base.org.admin.fields.created_at"), description: owner_time(account["created_at"]) },
            { term: t("base.org.admin.fields.active_sessions"), description: account.fetch("active_sessions").to_s },
          ]
        end

        def client_actions(public_id, data)
          actions = []
          if data.fetch("can_revoke_sessions")
            actions << { label: t("base.org.admin.revocations.action"),
                         href: new_base_org_support_client_revocation_path(public_id), }
          end
          if data.fetch("can_create_case")
            actions << { label: t("base.org.admin.enforcement.new_action"),
                         href: new_base_org_support_app_enforcement_case_path(principal_public_id: public_id), }
          end
          actions
        end

        def enforcement_section(cases)
          return nil if cases.nil?

          {
            heading: t("base.org.admin.enforcement.title"),
            links: cases.map do |row|
              { label: "#{row.fetch("public_id")} (#{row.fetch("kind")}, #{row.fetch("state")})",
                href: base_org_support_app_enforcement_case_path(row.fetch("public_id")), }
            end,
            empty_message: t("base.org.admin.enforcement.empty"),
          }
        end
      end
    end
  end
end
