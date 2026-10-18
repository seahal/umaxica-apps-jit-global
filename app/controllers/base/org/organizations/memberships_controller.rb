# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Organizations
      # Read-only view of a Bureau's Agent memberships, served by the owner (R5-WU15). Adding,
      # changing, or ending a membership is not provided (adr/operator-capability-authorization.md).
      class MembershipsController < Base::Org::ApplicationController
        include ::BaseMembershipRelay

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        MEMBERSHIP_SURFACE = "org"

        public

        def index
          page = params[:page].to_s
          raise ActionController::BadRequest, "page is malformed" unless page.empty? || page.match?(/\A[1-9]\d{0,3}\z/)
          raise ActionController::BadRequest, "page is out of range" if page.to_i > OrgAdministrationPage::MAX_PAGE

          result = membership_result!(
            membership_authority.memberships(params.expect(:organization_id), page: page.presence || 1),
          )
          render(json: result.data.slice("memberships", "page", "next_page")) if result
        end

        def show
          result = membership_result!(
            membership_authority.membership(
              params.expect(:organization_id),
              params.expect(:id),
            ),
          )
          render(json: result.data.except("can_edit")) if result
        end
      end
    end
  end
end
