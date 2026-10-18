# typed: false
# frozen_string_literal: true

module Base
  module Com
    module Identity
      class StandingsController < ::Base::Com::ApplicationController
        include ::SurfaceInertiaPage
        include ::OrgOwnerPageRelay

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private
        OWNER_PAGE_SURFACE = "com"

        public

        # R5-WU12: the standing is resolved by the Enforcement owner over HTTPS.
        def show
          relay_owner_page!
        end
      end
    end
  end
end
