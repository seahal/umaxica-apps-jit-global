# typed: false
# frozen_string_literal: true

module Base
  module Org
    class ConfigurationsController < Base::Org::ApplicationController
      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private

      def show
        # Closed for every operator: no authoritative configuration data source is exposed here yet
        # (adr/operator-capability-authorization.md, Not provided).
        authorize!(:org_console, to: :configuration?, with: OrgConsolePolicy)
        head :not_implemented
      end
    end
  end
end
