# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Iam
      module Grants
        # adr/operator-capability-authorization.md, IAM: revoking one capability grant. The model
        # refuses to revoke the last in-force holder of a continuity capability.
        class RevocationsController < Base::Org::ApplicationController
          include ::SurfaceInertiaPage
          include ::OrgAdministrationPage
          include ::OrgAdminRelay

          AUTHENTICATION_MODE = :private
          AUDIT_ACTION = "iam.capability.revoked"
          STEP_UP_SCOPE = "operator_capability"
          declare_authentication_mode! :private

          before_action :no_store

          public

          def new
            result = org_admin_result!(org_admin_authority.get(grant_path))
            return unless result

            # The owner's own decision; a refusal goes through the same authorization handler.
            unless result.data.fetch("can_revoke")
              refused = AvatarAuthorityClient::Result.new(status: :forbidden, data: {}, errors: {})
              authorize!(refused, to: :show?, with: AvatarRemoteResultPolicy)
            end

            render inertia: "base/org/iam/grants/revocations/new", props: confirmation_props(result.data.fetch("grant"))
          end

          def create
            keys = %i(reason_code operation_id)
            result = org_admin_result!(
              org_admin_authority.post(
                "#{grant_path}/revocation",
                params.slice(*keys).permit(*keys).to_h,
              ),
            )
            return unless result
            return redirect_to(base_org_iam_grant_path(grant_ref), status: :see_other) if result.ok?

            grant = org_admin_authority.get(grant_path).data.to_h.fetch("grant", { "public_id" => grant_ref })
            render inertia: "base/org/iam/grants/revocations/new",
                   props: confirmation_props(grant, errors: result.errors), status: org_admin_status(result)
          end

          private

          def grant_ref = params.expect(:grant_id)

          def grant_path = "/iam/grants/#{ERB::Util.url_encode(grant_ref)}"

          def no_store
            response.headers["Cache-Control"] = "private, no-store"
          end

          def confirmation_props(grant, errors: {})
            {
              title: t("base.org.admin.grants.revoke_title"),
              up_link: { label: grant.fetch("public_id"), href: base_org_iam_grant_path(grant.fetch("public_id")) },
              context: admin_context(realm: nil),
              target: [
                { term: t("base.org.admin.fields.grant_id"), description: grant.fetch("public_id") },
                { term: t("base.org.admin.fields.operator"), description: grant["operator_public_id"] },
                { term: t("base.org.admin.fields.capability"), description: grant["capability"] },
                { term: t("base.org.admin.fields.expires_at"),
                  description: admin_time(grant["expires_at"] && Time.zone.parse(grant["expires_at"])), },
              ],
              effect: t("base.org.admin.grants.revoke_effect"),
              action: base_org_iam_grant_revocation_path(grant.fetch("public_id")),
              fields: [
                { kind: "select",
                  name: "reason_code",
                  label: t("base.org.admin.fields.reason_code"),
                  value: "",
                  options: OperatorCapabilityGrant::REVOKE_REASON_CODES.map { |code| { value: code, label: code } }, },
                { kind: "hidden", name: "operation_id", value: admin_operation_id },
              ],
              acknowledgement: t("base.org.admin.grants.revoke_acknowledgement"),
              submit_label: t("base.org.admin.grants.revoke_submit"),
              errors: errors,
            }
          end
        end
      end
    end
  end
end
