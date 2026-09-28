# typed: false
# frozen_string_literal: true

module Base
  module Org
    class BillingController < Base::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def index
        # Closed for every operator: this application owns no authoritative billing data source yet
        # (adr/operator-capability-authorization.md, Not provided). The policy denies before any
        # response is rendered.
        authorize!(:org_console, to: :billing?, with: OrgConsolePolicy)
        head :not_implemented
      end
    end
  end
end
