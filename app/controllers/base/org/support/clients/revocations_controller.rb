# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      module Clients
        # adr/operator-capability-authorization.md, Support: forced revocation of an app-realm
        # Client's sessions. It ends the sessions that exist when the revocation reads them; it is
        # not an access lock, so the Client may sign in again afterwards.
        #
        # Order: authenticate, load the target, authorize the capability, then Step-Up. An operator
        # without the capability is refused before any Step-Up ceremony can start.
        class RevocationsController < Base::Org::ApplicationController
          include ::SurfaceInertiaPage
          include ::OrgAdministrationPage
          include ::OrgAdministrativeAudit
          include ::OrgSupportSessionRevocationPage
          include ::OrgAdminRelay

          AUTHENTICATION_MODE = :private
          REALM = "app"
          STEP_UP_SCOPE = "support_session_revoke"
          declare_authentication_mode! :private

          before_action :no_store

          public

          def show
            result = org_admin_result!(org_admin_authority.get("#{account_path}/revocations/#{ERB::Util.url_encode(params.expect(:id))}"))
            return unless result

            data = result.data
            render inertia: "base/org/support/revocations/show", props: {
              title: t("base.org.admin.revocations.show_title"),
              up_link: { label: account_ref, href: base_org_support_client_path(account_ref) },
              context: admin_context(realm: REALM),
              notices: data.fetch("notices").map(&:symbolize_keys),
              fields: [
                { term: t("base.org.admin.fields.operation_id"), description: data.fetch("event_uuid") },
                { term: t("base.org.admin.fields.result"), description: data.fetch("result_label") },
                { term: t("base.org.admin.fields.target"), description: account_ref },
                { term: t("base.org.admin.fields.performed_by"),
                  description: data["performed_by"] || t("base.org.admin.values.none"), },
                { term: t("base.org.admin.fields.reason_code"), description: data["reason_code"].to_s },
                { term: t("base.org.admin.fields.ticket_id"),
                  description: data["ticket_id"] || t("base.org.admin.values.none"), },
                { term: t("base.org.admin.fields.occurred_at"),
                  description: admin_time(data["occurred_at"] && Time.zone.parse(data["occurred_at"])), },
                { term: t("base.org.admin.fields.revoked_count"), description: data["revoked_count"].to_s },
              ],
              actions: [],
              sections: [],
            }
          end

          def new
            result = org_admin_result!(org_admin_authority.get("#{account_path}/revocation-screen"))
            return unless result

            render inertia: "base/org/support/revocations/new", props: confirmation_props(result.data.fetch("account"))
          end

          def create
            keys = %i(reason_code ticket_id operation_id)
            result = org_admin_result!(
              org_admin_authority.post(
                "#{account_path}/revocations",
                params.slice(*keys).permit(*keys).to_h,
              ),
            )
            return unless result

            if result.ok?
              redirect_to(
                base_org_support_client_revocation_path(account_ref, result.data.fetch("event_uuid")),
                status: :see_other,
              )
            else
              account = org_admin_authority.get(account_path).data.to_h.fetch("account", { "public_id" => account_ref })
              values = (result.status == :unprocessable) ? submitted_values : {}
              render inertia: "base/org/support/revocations/new",
                     props: confirmation_props(account, errors: result.errors, values:),
                     status: org_admin_status(result)
            end
          end

          private

          def account_ref = params.expect(:client_id)

          def account_path = "/support/app/accounts/#{ERB::Util.url_encode(account_ref)}"

          def no_store
            response.headers["Cache-Control"] = "private, no-store"
          end

          def confirmation_props(account, errors: {}, values: {})
            target = Struct.new(:public_id, :access_state, :active_session_count)
              .new(account.fetch("public_id"), account["access_state"], account["active_sessions"])
            revocation_confirmation_props(
              target:, realm: REALM, errors:, values:,
              action_path: base_org_support_client_revocations_path(account_ref),
              up_link: { label: account_ref, href: base_org_support_client_path(account_ref) },
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
