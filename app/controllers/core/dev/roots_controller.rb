# typed: false
# frozen_string_literal: true

module Core
  module Dev
    class RootsController < Core::Dev::BareController
      AUTHENTICATION_MODE = :deny_all

      # Declared here rather than on BareController: that base is also the parent of the
      # api/v0/health, revision, and CSP report endpoints, where a browser-version gate would
      # answer a machine client with public/406-unsupported-browser.html.
      allow_browser versions: :modern
      layout false

      def index
      end
    end
  end
end
