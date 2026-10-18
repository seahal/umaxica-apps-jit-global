# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Support
      # adr/unified-enforcement.md, Approval / Operator safety, and
      # adr/operator-capability-authorization.md. Noun-resource controller per
      # .agents/harnesses/rules/generic/routing.mdc -- no `ban`/`approve`/`release` actions here;
      # those are the nested `approval`, `release`, and `appeal_review` resources.
      #
      # Reading (index/show) needs only the realm's read capability. Applying (new/create) needs the
      # apply capability and the `enforcement_case_apply` Step-Up, checked in that order. The
      # applying operator and every approver are taken from the session, never from the request.
      class EnforcementCasesController < Base::Org::ApplicationController
        include ::OrgOwnerPageRelay

        AUTHENTICATION_MODE = :private
        declare_authentication_mode! :private

        before_action :no_store

        public

        # R5-WU12: decided, written and composed by the Enforcement owner over HTTPS.
        def index
          relay_owner_page!
        end

        # R5-WU12: decided, written and composed by the Enforcement owner over HTTPS.
        def show
          relay_owner_page!
        end

        # R5-WU12: decided, written and composed by the Enforcement owner over HTTPS.
        def new
          relay_owner_page!
        end

        # R5-WU12: decided, written and composed by the Enforcement owner over HTTPS.
        def create
          relay_owner_page!
        end

        private

        def no_store
          response.headers["Cache-Control"] = "private, no-store"
        end
      end
    end
  end
end
