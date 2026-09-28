# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      # adr/operator-capability-authorization.md, Support: com-realm Visitors, looked up only by their
      # public id. The page shows account and session state, never identifiers such as email
      # addresses, credentials, or tokens.
      class VisitorsController < Base::Org::ApplicationController
        include ::SurfaceInertiaPage
        include ::OrgAdministrationPage

        AUTHENTICATION_MODE = :private
        REALM = "com"
        declare_authentication_mode! :private

        before_action :authenticate_operator!
        before_action :no_store

        public

        def index
          authorize!(Visitor, to: :index?, with: SupportVisitorPolicy)
          query = admin_query
          relation = Visitor.order(created_at: :desc, id: :desc)
          relation = relation.where(public_id: query) if query
          visitors, page, more = admin_paginate(relation)

          render inertia: "base/org/support/visitors/index",
                 props: {
                   title: t("base.org.admin.visitors.title"),
                   up_link: { label: t("base.org.admin.support.title"), href: base_org_support_index_path },
                   context: admin_context(realm: REALM),
                   columns: [t("base.org.admin.fields.public_id"), t("base.org.admin.fields.access_state"),
                             t("base.org.admin.fields.created_at"),],
                   rows: visitors.map { |visitor| visitor_row(visitor) },
                   empty_message: t("base.org.admin.visitors.empty"),
                   search: {
                     action: base_org_support_visitors_path,
                     label: t("base.org.admin.search.public_id"),
                     name: "q",
                     value: query.to_s,
                     submit_label: t("base.org.admin.search.submit"),
                     maxlength: OrgAdministrationPage::MAX_QUERY_LENGTH,
                   },
                   pagination: admin_pagination_links(
                     page: page,
                     more: more,
                     path_builder: ->(number) { base_org_support_visitors_path(q: query, page: number) },
                   ),
                   actions: [],
                 }
        end

        def show
          visitor = Visitor.find_by!(public_id: params.expect(:id))
          authorize!(visitor, to: :show?, with: SupportVisitorPolicy)

          render inertia: "base/org/support/visitors/show",
                 props: {
                   title: t("base.org.admin.visitors.show_title", public_id: visitor.public_id),
                   up_link: { label: t("base.org.admin.visitors.title"),
                              href: base_org_support_visitors_path, },
                   context: admin_context(realm: REALM),
                   fields: account_fields(visitor),
                   actions: visitor_actions(visitor),
                   sections: [enforcement_section(visitor)].compact,
                 }
        end

        private

        def no_store
          response.headers["Cache-Control"] = "private, no-store"
        end

        def visitor_row(visitor)
          {
            key: visitor.public_id,
            cells: [visitor.public_id, visitor.access_state, admin_time(visitor.created_at)],
            href: base_org_support_visitor_path(visitor.public_id),
          }
        end

        def account_fields(visitor)
          [
            { term: t("base.org.admin.fields.public_id"), description: visitor.public_id },
            { term: t("base.org.admin.fields.access_state"), description: visitor.access_state },
            { term: t("base.org.admin.fields.created_at"), description: admin_time(visitor.created_at) },
            {
              term: t("base.org.admin.fields.active_sessions"),
              description: AuthenticationSessionRevoker.tokens_for(visitor).not_revoked.count.to_s,
            },
          ]
        end

        def visitor_actions(visitor)
          actions = []
          if allowed_to?(:revoke_sessions?, visitor, with: SupportVisitorPolicy)
            actions << {
              label: t("base.org.admin.revocations.action"),
              href: new_base_org_support_visitor_revocation_path(visitor.public_id),
            }
          end
          if allowed_to?(:create?, ComEnforcementCase.new, with: EnforcementCasePolicy)
            actions << {
              label: t("base.org.admin.enforcement.new_action"),
              href: new_base_org_support_com_enforcement_case_path(principal_public_id: visitor.public_id),
            }
          end
          actions
        end

        def enforcement_section(visitor)
          return nil unless allowed_to?(:index?, ComEnforcementCase.new, with: EnforcementCasePolicy)

          cases = ComEnforcementCase.where(principal_public_id: visitor.public_id).order(created_at: :desc).limit(20)
          {
            heading: t("base.org.admin.enforcement.title"),
            links: cases.map do |enforcement_case|
              {
                label: "#{enforcement_case.public_id} (#{enforcement_case.kind}, #{enforcement_case.state})",
                href: base_org_support_com_enforcement_case_path(enforcement_case.public_id),
              }
            end,
            empty_message: t("base.org.admin.enforcement.empty"),
          }
        end
      end
    end
  end
end
