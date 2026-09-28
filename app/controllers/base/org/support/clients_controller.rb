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

        AUTHENTICATION_MODE = :private
        REALM = "app"
        declare_authentication_mode! :private

        before_action :authenticate_operator!
        before_action :no_store

        public

        def index
          authorize!(Client, to: :index?, with: SupportClientPolicy)
          query = admin_query
          relation = Client.order(created_at: :desc, id: :desc)
          relation = relation.where(public_id: query) if query
          clients, page, more = admin_paginate(relation)

          render inertia: "base/org/support/clients/index",
                 props: {
                   title: t("base.org.admin.clients.title"),
                   up_link: { label: t("base.org.admin.support.title"), href: base_org_support_index_path },
                   context: admin_context(realm: REALM),
                   columns: [t("base.org.admin.fields.public_id"), t("base.org.admin.fields.access_state"),
                             t("base.org.admin.fields.created_at"),],
                   rows: clients.map { |client| client_row(client) },
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
                     page: page,
                     more: more,
                     path_builder: ->(number) { base_org_support_clients_path(q: query, page: number) },
                   ),
                   actions: [],
                 }
        end

        def show
          client = Client.find_by!(public_id: params.expect(:id))
          authorize!(client, to: :show?, with: SupportClientPolicy)

          render inertia: "base/org/support/clients/show",
                 props: {
                   title: t("base.org.admin.clients.show_title", public_id: client.public_id),
                   up_link: { label: t("base.org.admin.clients.title"), href: base_org_support_clients_path },
                   context: admin_context(realm: REALM),
                   fields: account_fields(client),
                   actions: client_actions(client),
                   sections: [enforcement_section(client)].compact,
                 }
        end

        private

        def no_store
          response.headers["Cache-Control"] = "private, no-store"
        end

        def client_row(client)
          {
            key: client.public_id,
            cells: [client.public_id, client.access_state, admin_time(client.created_at)],
            href: base_org_support_client_path(client.public_id),
          }
        end

        def account_fields(client)
          [
            { term: t("base.org.admin.fields.public_id"), description: client.public_id },
            { term: t("base.org.admin.fields.access_state"), description: client.access_state },
            { term: t("base.org.admin.fields.created_at"), description: admin_time(client.created_at) },
            {
              term: t("base.org.admin.fields.active_sessions"),
              description: AuthenticationSessionRevoker.tokens_for(client).not_revoked.count.to_s,
            },
          ]
        end

        def client_actions(client)
          actions = []
          if allowed_to?(:revoke_sessions?, client, with: SupportClientPolicy)
            actions << {
              label: t("base.org.admin.revocations.action"),
              href: new_base_org_support_client_revocation_path(client.public_id),
            }
          end
          if allowed_to?(:create?, AppEnforcementCase.new, with: EnforcementCasePolicy)
            actions << {
              label: t("base.org.admin.enforcement.new_action"),
              href: new_base_org_support_app_enforcement_case_path(principal_public_id: client.public_id),
            }
          end
          actions
        end

        def enforcement_section(client)
          return nil unless allowed_to?(:index?, AppEnforcementCase.new, with: EnforcementCasePolicy)

          cases = AppEnforcementCase.where(principal_public_id: client.public_id).order(created_at: :desc).limit(20)
          {
            heading: t("base.org.admin.enforcement.title"),
            links: cases.map do |enforcement_case|
              {
                label: "#{enforcement_case.public_id} (#{enforcement_case.kind}, #{enforcement_case.state})",
                href: base_org_support_app_enforcement_case_path(enforcement_case.public_id),
              }
            end,
            empty_message: t("base.org.admin.enforcement.empty"),
          }
        end
      end
    end
  end
end
