# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class FullAccessController < ::Auth::Org::ApplicationController
      # D-59: no route reaches the controller yet; it remains explicitly non-entry rather than
      # inheriting an implicit classification.
      sign_entry_classification! :excluded, reason: "signed-in full-access confirmation surface"

      AUTHENTICATION_MODE = :private
      declare_authentication_mode! :private
    end
  end
end
