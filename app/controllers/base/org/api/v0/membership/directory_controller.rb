# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Api
      module V0
        module Membership
          # Account, organization and membership owner for the org Base Self-RP (R5-WU15, same
          # approved pattern as the Avatar contract). Lists and decisions come from the existing
          # BaseSwitcherAuthority scope and AccountPolicy / OrganizationPolicy /
          # OrganizationMembershipPolicy; unsupported membership writes stay unsupported.
          class DirectoryController < ActionController::API
            include ::DefaultNoStore

            prepend_before_action :apply_default_no_store
            include ActionPolicy::Controller
            include ::ActorSupport
            include ::AvatarAuthorityApiEndpoint

            AUTHENTICATION_MODE = :open
            AVATAR_SURFACE = "org"
            RULES = %w(index? show? new? create? edit? update? destroy?).freeze
            PER_PAGE = 50

            authorize :user, through: :avatar_actor
            around_action :with_actor_lifecycle
            before_action :authenticate_avatar_caller!
            before_action :set_current_actor
            rescue_from ActionPolicy::Unauthorized, with: :render_forbidden
            rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
            rescue_from ActionController::ParameterMissing, with: :render_bad_request

            public

            def accounts
              authorize!(avatar_actor, to: :show?)
              render json: { accounts: avatar_switcher.available_accounts.map { |account|
                { public_id: account.public_id }
              } }
            end

            def account
              account = avatar_switcher.find_account(params.expect(:ref)) || raise(ActiveRecord::RecordNotFound)
              authorize!(account, to: :show?, with: AccountPolicy)
              render json: { account: { public_id: account.public_id } }
            end

            def organizations
              authorize!(avatar_actor, to: :show?)
              render json: {
                organizations: avatar_switcher.available_organizations.map { |row| { public_id: row.public_id } },
              }
            end

            def organization
              organization = avatar_switcher.find_organization(params.expect(:ref)) || raise(ActiveRecord::RecordNotFound)
              authorize!(organization, to: :show?, with: OrganizationPolicy)
              render json: { organization: { public_id: organization.public_id },
                             memberships: membership_summary(organization), }
            end

            def memberships
              organization = membership_organization
              authorize!(organization, to: :index?, with: OrganizationMembershipPolicy)
              page = membership_page
              rows = organization.agent_memberships.order(:id).offset((page - 1) * PER_PAGE)
                .limit(PER_PAGE + 1).to_a
              visible =
                rows.first(PER_PAGE).select { |row|
                  allowed_to?(:show?, row, with: OrganizationMembershipPolicy)
                }
              render json: {
                memberships: visible.map { |row| membership_json(row) },
                page:,
                next_page: (rows.length > PER_PAGE) ? page + 1 : nil,
                can_new: allowed_to?(:new?, organization, with: OrganizationMembershipPolicy),
              }
            rescue ActionController::BadRequest
              render_bad_request
            end

            def membership
              row = membership_organization.agent_memberships.find(params.expect(:id))
              authorize!(row, to: :show?, with: OrganizationMembershipPolicy)
              render json: membership_json(row).merge(
                can_edit: allowed_to?(
                  :edit?, row,
                  with: OrganizationMembershipPolicy,
                ),
              )
            end

            # Decision only: the record is the organization for collection rules, else the membership.
            def authorization
              rule = params.expect(:rule)
              return render_bad_request unless RULES.include?(rule)

              organization = membership_organization
              # The membership id is optional: absent means the decision is about the organization itself.
              membership_id = params.slice(:id).permit(:id)[:id]
              record = membership_id.present? ? organization.agent_memberships.find(membership_id) : organization
              render json: { allowed: allowed_to?(rule.to_sym, record, with: OrganizationMembershipPolicy) }
            end

            private

            # Same page contract as the former page: absent/blank is 1, otherwise 1..9999 digits only.
            def membership_page
              value = params[:page]
              return 1 if value.nil? || value == ""
              raise ActionController::BadRequest, "page is malformed" unless
                value.is_a?(String) && value.match?(/\A[1-9]\d{0,3}\z/)

              page = value.to_i
              raise ActionController::BadRequest, "page is out of range" if page > OrgAdministrationPage::MAX_PAGE

              page
            end

            def membership_organization = Bureau.find_by!(public_id: params.expect(:organization_ref))

            def membership_summary(organization)
              return { can_index: false } unless allowed_to?(:index?, organization, with: OrganizationMembershipPolicy)

              {
                can_index: true,
                can_new: allowed_to?(:new?, organization, with: OrganizationMembershipPolicy),
                entries: organization.agent_memberships.order(:id).filter_map do |row|
                  next unless allowed_to?(:show?, row, with: OrganizationMembershipPolicy)

                  { id: row.id, can_edit: allowed_to?(:edit?, row, with: OrganizationMembershipPolicy) }
                end,
              }
            end

            def membership_json(row)
              base = { id: row.id }
              return base unless row.respond_to?(:agent)

              base.merge(
                agent_public_id: row.agent.public_id, membership_kind_id: row.membership_kind_id,
                membership_state_id: row.membership_state_id, primary: row.primary, starts_at: row.starts_at,
                ends_at: row.ends_at, revoked_at: row.revoked_at,
              )
            end
          end
        end
      end
    end
  end
end
