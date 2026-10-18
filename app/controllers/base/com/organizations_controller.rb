# typed: false
# frozen_string_literal: true

module Base
  module Com
    class OrganizationsController < Base::Com::ApplicationController
      include ::SurfaceInertiaPage

      include ::BaseMembershipRelay

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      MEMBERSHIP_SURFACE = "com"

      public

      # R5-WU15: listed and authorized by the owner over HTTPS.
      def index
        result = membership_result!(membership_authority.organizations)
        return unless result

        @organizations = result.data.fetch("organizations")
        render inertia: true, props: { title: "Organizations", body: "organizations", up_link: dashboard_up_link }
      end

      def show
        result = membership_result!(membership_authority.organization(params.expect(:id)))
        return unless result

        @organization = result.data.fetch("organization")
        render inertia: true, props: { title: "Organization", body: "organization" }
      end
    end
  end
end
