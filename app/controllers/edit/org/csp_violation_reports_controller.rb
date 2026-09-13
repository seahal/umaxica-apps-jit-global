# typed: false
# frozen_string_literal: true

module Edit
  module Org
    class CspViolationReportsController < BareController
      include CspViolationReport

      AUTHENTICATION_MODE = :bare
      protect_csp_violation_report_intake
      rescue_from ActionDispatch::Http::Parameters::ParseError, with: :ignore_malformed_csp_report

      public

      def create
        record_csp_violation!

        head :no_content
      end
    end
  end
end
