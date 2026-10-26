# typed: false
# frozen_string_literal: true

module Tech
  module Org
    module Oidc
      class CallbacksController < Tech::Org::ApplicationController
        include ::OidcCallback
        include ::OidcRpIdentityProvisioning

        AUTHENTICATION_MODE = :open
        class_attribute :oidc_rp_actor_class, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        class_attribute :oidc_rp_identity_class, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        class_attribute :oidc_rp_binding_class, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        class_attribute :oidc_rp_bridge_class, instance_accessor: false # rubocop:disable ThreadSafety/ClassAndModuleAttributes
        provisions_oidc_rp_identity actor_class: Operator, identity_class: OperatorIdentity,
                                    binding_class: OperatorOidcIdentityBinding
        declare_authentication_mode! :open

        skip_before_action :set_region, raise: false

        private

        def oidc_client_id
          "tech-org-ww"
        end

        def oidc_rp_credentials_only?
          true
        end

        def provision_rp_account_from_id_token!(verification_result, authoritative_resource: nil)
          super
        rescue ActionPolicy::Unauthorized
          revoke_failed_callback_rp_session!(
            sid: verification_result.payload.to_h["sid"],
            operator: authoritative_resource,
          )
          raise
        end

        def verify_binding_resource!(actor, authoritative_resource, claims)
          super
          authorize!(actor, to: :show?, with: TechAccessPolicy)
        end

        def render_oidc_access_denied!
          clear_oidc_session_state!
          response.set_header("Cache-Control", "no-store")
          render "tech/org/access_denials/show", status: :forbidden
        end

        # The signed ID Token's sid names only the RP Session created by this callback. Revoke that
        # child if the writer-backed policy check loses a race with grant revocation; preserve its
        # parent Browser Session and every other RP session.
        def revoke_failed_callback_rp_session!(sid:, operator:)
          return unless operator.is_a?(Operator) && sid.is_a?(String) && sid.present?

          OpBaseOrgRecord.connected_to(role: :writing) do
            usage = OpOrgGrant.lock.find_by(public_id: sid, oidc_client_id: "tech-org-ww")
            return unless usage && OperatorToken.exists?(
              id: usage.operator_token_id,
              staff_id: operator.id,
              device_session_id: usage.device_session_id,
            )

            # A rejected callback ends only the exact RP grant it just authenticated.
            unless usage.revoked?
              OpAuthorityStopCommitter.stop_grant(
                grant: usage, cause: "token_revocation", principal_public_id: operator.public_id.to_s,
                authority_evidence_ref: "tech_callback_refused",
              )
            end
          end
        end
      end
    end
  end
end
