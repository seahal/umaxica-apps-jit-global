# typed: false
# frozen_string_literal: true

module Auth
  module App
    class ServiceWorkerRetirementsController < BareController
      include ::ServiceWorkerRetirement

      AUTHENTICATION_MODE = :bare

      # The body is a public constant, so the cross-origin JavaScript guard protects nothing here, and
      # the browser's Worker fetch is not an XHR that could pass it.
      skip_forgery_protection only: :show
    end
  end
end
