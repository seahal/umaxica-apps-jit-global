# typed: false
# frozen_string_literal: true

module Base
  module Org
    class AccountsController < Base::Org::ApplicationController
      include ::SurfaceInertiaPage

      include ::BaseMembershipRelay

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      MEMBERSHIP_SURFACE = "org"

      public

      # R5-WU15: listed and authorized by the owner over HTTPS.
      def index
        result = membership_result!(membership_authority.accounts)
        return unless result

        @accounts = result.data.fetch("accounts")
        render inertia: true, props: { title: "Account", body: "account", up_link: dashboard_up_link }
      end

      def show
        result = membership_result!(membership_authority.account(params.expect(:id)))
        return unless result

        @account = result.data.fetch("account")
        render inertia: true, props: { title: "Account", body: "account" }
      end
    end
  end
end
