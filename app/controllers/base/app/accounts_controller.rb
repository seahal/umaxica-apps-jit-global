# typed: false
# frozen_string_literal: true

module Base
  module App
    # Account entity management for the app surface. Plural CRUD over the accounts the
    # signed-in client may act as; changing the *current* account is the switcher's job, not this
    # controller's. Requires a selected actor context (FullAccessController).
    class AccountsController < Base::App::FullAccessController
      include ::SurfaceInertiaPage

      include ::BaseMembershipRelay

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      MEMBERSHIP_SURFACE = "app"

      public

      # R5-WU15: listed and authorized by the owner over HTTPS.
      def index
        result = membership_result!(membership_authority.accounts)
        return unless result

        render inertia: true, props: {
          title: "Accounts",
          body: "account",
          empty: "None available",
          entries: result.data.fetch("accounts").map { |account| serialize_account(account.fetch("public_id")) },
          create_action: { label: "Create Account" },
          up_link: dashboard_up_link,
        }
      end

      def show
        return unless membership_result!(membership_authority.account(params.expect(:id)))

        render inertia: true, props: {
          title: "Account",
          body: "account",
          up_link: { label: t("actions.up"), href: base_app_accounts_path(ri: params[:ri]) },
        }
      end

      private

      def serialize_account(public_id)
        { public_id:, label: public_id, href: base_app_account_path(public_id, ri: params[:ri]) }
      end
    end
  end
end
