# typed: false
# frozen_string_literal: true

module Core
  module Org
    class ConfigurationsController < Core::Org::ApplicationController
      AUTHENTICATION_MODE = :private

      def show
        # Closed for every operator: no authoritative configuration data source is exposed here yet
        # (adr/operator-capability-authorization.md, Not provided).
        authorize!(:org_console, to: :configuration?, with: OrgConsolePolicy)
        render template: "acme/org/roots/index"
      end
    end
  end
end
