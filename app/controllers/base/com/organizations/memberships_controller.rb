# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Organizations
      class MembershipsController < Base::Com::ApplicationController
        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :set_organization
        before_action :set_membership, only: %i(show edit update destroy)

        def index
          authorize!(@organization, to: :index?, with: OrganizationMembershipPolicy)
          render json: []
        end

        def show
          authorize!(@membership, to: :show?, with: OrganizationMembershipPolicy)
          render json: {}
        end

        def new
          authorize!(@organization, to: :new?, with: OrganizationMembershipPolicy)
          render plain: "New Membership"
        end

        def edit
          authorize!(@membership, to: :edit?, with: OrganizationMembershipPolicy)
          render plain: "Edit Membership"
        end

        def create
          authorize!(@organization, to: :create?, with: OrganizationMembershipPolicy)
          head :unprocessable_content
        end

        def update
          authorize!(@membership, to: :update?, with: OrganizationMembershipPolicy)
          head :unprocessable_content
        end

        def destroy
          authorize!(@membership, to: :destroy?, with: OrganizationMembershipPolicy)
          head :no_content
        end

        private

        def set_organization
          @organization = Company.find_by!(public_id: params.expect(:organization_id))
        end

        def set_membership
          @membership = @organization.individual_memberships.find(params.expect(:id))
        end
      end
    end
  end
end
