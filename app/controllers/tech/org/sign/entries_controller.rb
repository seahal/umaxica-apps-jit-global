# typed: false
# frozen_string_literal: true

module Tech
  module Org
    module Sign
      class EntriesController < Tech::Org::ApplicationController
        include ::OidcRpSignEntry

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        before_action :reject_authenticated_rp_start!
        helper_method :neutral_sign_form_url, :neutral_sign_target_link_uri

        private
      end
    end
  end
end
