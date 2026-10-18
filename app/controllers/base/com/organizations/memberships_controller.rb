# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Organizations
      # Company memberships for the com Base Self-RP; decided by the owner (R5-WU15). Writes stay
      # unsupported exactly as before.
      class MembershipsController < Base::Com::ApplicationController
        include ::BaseMembershipRelay

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        MEMBERSHIP_SURFACE = "com"

        public

        def index
          render(json: []) if decide!("index?")
        end

        def show
          render(json: {}) if decide!("show?", id: params.expect(:id))
        end

        def new
          render(plain: "New Membership") if decide!("new?")
        end

        def edit
          render(plain: "Edit Membership") if decide!("edit?", id: params.expect(:id))
        end

        def create
          head(:unprocessable_content) if decide!("create?")
        end

        def update
          head(:unprocessable_content) if decide!("update?", id: params.expect(:id))
        end

        def destroy
          head(:no_content) if decide!("destroy?", id: params.expect(:id))
        end

        private

        # Every action asks the owner for its membership decision; only an explicit allow passes.
        def decide!(rule, id: nil)
          result = membership_authority.authorization(params.expect(:organization_id), rule, id:)
          membership_result!(result)
        end
      end
    end
  end
end
