# typed: false
# frozen_string_literal: true

module Base
  module Org
    class AccountsController < Base::Org::ApplicationController
      include ::SurfaceInertiaPage

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      before_action :authenticate_operator!

      def index
        authorize!(current_operator, to: :show?)
        @accounts = switcher.available_accounts
        render inertia: true, props: { title: "Account", body: "account", up_link: dashboard_up_link }
      end

      def show
        @account = find_account!
        authorize!(@account, to: :show?, with: AccountPolicy)
        render inertia: true, props: { title: "Account", body: "account" }
      end

      private

      def find_account!
        switcher.find_account(params.expect(:id)) || raise(ActiveRecord::RecordNotFound)
      end

      def switcher
        @switcher ||= BaseSwitcherAuthority.new(
          surface: :org, principal: current_operator, session: current_session,
        )
      end
    end
  end
end
