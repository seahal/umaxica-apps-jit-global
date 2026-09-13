# typed: false
# frozen_string_literal: true

module Base
  module App
    # Account entity management for the app surface. Plural CRUD over the accounts the
    # signed-in client may act as; changing the *current* account is the switcher's job, not this
    # controller's. Requires a selected actor context (FullAccessController).
    class AccountsController < Base::App::FullAccessController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_client!

      def index
        authorize!(current_client, to: :show?)
        accounts = switcher.available_accounts

        render inertia: true, props: {
          title: "Accounts",
          body: "account",
          empty: "None available",
          entries: accounts.map { |account| serialize_account(account) },
          up_link: dashboard_up_link,
        }
      end

      def show
        account = find_account!
        authorize!(account, to: :show?, with: AccountPolicy)

        render inertia: true, props: { title: "Account", body: "account" }
      end

      private

      def serialize_account(account)
        {
          public_id: account.public_id,
          label: account.public_id,
          href: base_app_account_path(account.public_id, ri: params[:ri]),
        }
      end

      # Scoped to the principal's available accounts: a foreign or non-existent id raises
      # RecordNotFound (404), which is the authoritative ownership gate for show/edit/update.
      def find_account!
        switcher.find_account(params.expect(:id)) || raise(ActiveRecord::RecordNotFound)
      end

      def switcher
        @switcher ||= BaseSwitcherAuthority.new(
          surface: :app, principal: current_client, session: current_session,
        )
      end
    end
  end
end
