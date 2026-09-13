# typed: false
# frozen_string_literal: true

module Base
  module Com
    class OrganizationsController < Base::Com::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_visitor!

      def index
        authorize!(current_visitor, to: :show?)
        @organizations = switcher.available_organizations
        render inertia: true, props: { title: "Organizations", body: "organizations", up_link: dashboard_up_link }
      end

      def show
        @organization = find_organization!
        authorize!(@organization, to: :show?, with: OrganizationPolicy)
        render inertia: true, props: { title: "Organization", body: "organization" }
      end

      private

      def find_organization!
        switcher.find_organization(params.expect(:id)) || raise(ActiveRecord::RecordNotFound)
      end

      def switcher
        @switcher ||= BaseSwitcherAuthority.new(
          surface: :com, principal: current_visitor, session: current_session,
        )
      end
    end
  end
end
