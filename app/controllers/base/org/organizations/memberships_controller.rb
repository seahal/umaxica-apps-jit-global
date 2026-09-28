# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Organizations
      # Read-only view of a Bureau's Agent memberships. Adding, changing, or ending a membership is
      # not routed on org: the authority for it (BureauOwnership and BureauAdministrationGrant, or
      # the membership-level OWNER kind the selector bootstrap assigns) is not yet decided, and a
      # membership change must never reach the Operator itself (adr/operator-capability-authorization.md).
      class MembershipsController < Base::Org::ApplicationController
        include ::OrgAdministrationPage

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :authenticate_operator!
        before_action :set_organization
        before_action :set_membership, only: :show

        def index
          authorize!(@organization, to: :index?, with: OrganizationMembershipPolicy)
          memberships, page, more = admin_paginate(
            @organization.agent_memberships.includes(:agent).order(:id),
          )
          render json: {
            memberships: memberships.map { |membership| membership_json(membership) },
            page: page,
            next_page: more ? page + 1 : nil,
          }
        end

        def show
          authorize!(@membership, to: :show?, with: OrganizationMembershipPolicy)
          render json: membership_json(@membership)
        end

        private

        def set_organization
          @organization = Bureau.find_by!(public_id: params.expect(:organization_id))
        end

        def set_membership
          @membership = @organization.agent_memberships.includes(:agent).find(params.expect(:id))
        end

        def membership_json(membership)
          {
            id: membership.id,
            agent_public_id: membership.agent.public_id,
            membership_kind_id: membership.membership_kind_id,
            membership_state_id: membership.membership_state_id,
            primary: membership.primary,
            starts_at: membership.starts_at,
            ends_at: membership.ends_at,
            revoked_at: membership.revoked_at,
          }
        end
      end
    end
  end
end
